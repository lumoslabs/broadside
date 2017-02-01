require 'open3'
require 'shellwords'

module Broadside
  class EcsDeploy < Deploy
    DEFAULT_CONTAINER_DEFINITION = {
      cpu: 1,
      essential: true,
      memory: 1000
    }

    def initialize(target_name, opts = {})
      super(target_name, opts)
      Broadside.config.ecs.verify(:poll_frequency)
    end

    def deploy
      super do
        unless EcsManager.service_exists?(@target.cluster, @target.family)
          raise Error, "No service for '#{@target.family}'! Please bootstrap or manually configure one."
        end
        unless EcsManager.get_latest_task_definition_arn(@target.family)
          raise Error, "No task definition for '#{@target.family}'! Please bootstrap or manually configure one."
        end

        update_task_revision

        begin
          update_service
        rescue SignalException::Interrupt
          error 'Caught interrupt signal, rolling back...'
          rollback(1)
          error 'Deployment did not finish successfully.'
          raise
        rescue StandardError => e
          error e.inspect, "\n", e.backtrace.join("\n")
          error 'Deploy failed! Rolling back...'
          rollback(1)
          error 'Deployment did not finish successfully.'
          raise e
        end
      end
    end

    def bootstrap
      if EcsManager.get_latest_task_definition_arn(@target.family)
        info("Task definition for #{@target.family} already exists.")
      else
        unless @target.task_definition_config
          raise ArgumentError, "No first task definition and no :task_definition_config in '#{@target.family}' configuration"
        end

        info "Creating an initial task definition for '#{@target.family}' from the config..."

        EcsManager.ecs.register_task_definition(
          @target.task_definition_config.merge(
            family: @target.family,
            container_definitions: [DEFAULT_CONTAINER_DEFINITION.merge(container_definition)]
          )
        )
      end

      run_commands(@target.bootstrap_commands)

      if EcsManager.service_exists?(@target.cluster, @target.family)
        info("Service for #{@target.family} already exists.")
      else
        unless @target.service_config
          raise ArgumentError, "Service doesn't exist and no :service_config in '#{@target.family}' configuration"
        end

        info "Service '#{@target.family}' doesn't exist, creating..."
        EcsManager.create_service(@target.cluster, @target.family, @target.service_config)
      end
    end

    def rollback(count = @rollback)
      super do
        begin
          EcsManager.deregister_last_n_tasks_definitions(@target.family, count)
          update_service
        rescue StandardError
          error 'Rollback failed to complete!'
          raise
        end
      end
    end

    def scale
      super do
        update_service
      end
    end

    def run
      super do
        run_commands(@command)
      end
    end

    def logtail
      super do
        ip = get_running_instance_ip!
        debug "Tailing logs for running container at ip #{ip}..."
        search_pattern = Shellwords.shellescape(@target.family)
        cmd = "docker logs -f --tail=#{@lines} `docker ps -n 1 --quiet --filter name=#{search_pattern}`"
        tail_cmd = Broadside.config.ssh_cmd(ip) + " '#{cmd}'"
        exec(tail_cmd)
      end
    end

    def ssh
      super do
        ip = get_running_instance_ip!
        debug "Establishing an SSH connection to IP #{ip}..."
        exec(Broadside.config.ssh_cmd(ip))
      end
    end

    def bash
      super do
        ip = get_running_instance_ip!
        debug "Running bash for running container at IP #{ip}..."
        search_pattern = Shellwords.shellescape(@target.family)
        cmd = "docker exec -i -t `docker ps -n 1 --quiet --filter name=#{search_pattern}` bash"
        exec(Broadside.config.ssh_cmd(ip, tty: true) + " '#{cmd}'")
      end
    end

    private

    def get_running_instance_ip!(index = @instance, task_arns = nil)
      ips = EcsManager.get_running_instance_ips!(@target.cluster, @target.family, task_arns)
      raise "No running tasks found for '#{@target.name}'!" if ips.empty?
      ips.fetch(index)
    end

    # Creates a new task revision using current directory's env vars, provided tag, and configured options.
    # Currently can only handle a single container definition.
    def update_task_revision
      revision = EcsManager.get_latest_task_definition(@target.family).except(
        :requires_attributes,
        :revision,
        :status,
        :task_definition_arn
      )
      updatable_container_definitions = revision[:container_definitions].select { |c| c[:name] == @target.family }
      raise Error, "Can only update one container definition!" if updatable_container_definitions.size != 1

      # Deep merge doesn't work well with arrays (e.g. container_definitions), so build the container first.
      updatable_container_definitions.first.merge!(container_definition)
      revision.deep_merge!((@target.task_definition_config || {}).except(:container_definitions))

      task_definition = EcsManager.ecs.register_task_definition(revision).task_definition
      debug "Successfully created #{task_definition.task_definition_arn}"
    end

    # reloads the service using the latest task definition
    def update_service
      task_definition_arn = EcsManager.get_latest_task_definition_arn(@target.family)
      debug "Updating #{@target.family} with scale=#{@scale} using task_definition #{task_definition_arn}..."

      update_service_response = EcsManager.ecs.update_service({
        cluster: @target.cluster,
        desired_count: @scale,
        service: @target.family,
        task_definition: task_definition_arn
      }.deep_merge(@target.service_config || {}))

      unless update_service_response.successful?
        raise Error, "Failed to update service during deploy:\n#{update_service_response.pretty_inspect}"
      end

      EcsManager.ecs.wait_until(:services_stable, { cluster: @target.cluster, services: [@target.family] }) do |w|
        timeout = Broadside.config.timeout
        w.delay = Broadside.config.ecs.poll_frequency
        w.max_attempts = timeout ? timeout / w.delay : nil
        seen_event = nil

        w.before_wait do |attempt, response|
          debug "(#{attempt}/#{w.max_attempts ? w.max_attempts : Float::INFINITY}) Polling ECS for events..."
          # skip first event since it doesn't apply to current request
          if response.services[0].events.first && response.services[0].events.first.id != seen_event && attempt > 1
            seen_event = response.services[0].events.first.id
            debug(response.services[0].events.first.message)
          end
        end
      end
    end

    def run_commands(commands)
      return if commands.nil? || commands.empty?
      Broadside.config.verify(:ssh)
      update_task_revision

      begin
        Array.wrap(commands).each do |command|
          command_name = command.join(' ')
          run_task_response = EcsManager.run_task(@target.cluster, @target.family, command)

          unless run_task_response.successful? && run_task_response.tasks.try(:[], 0)
            raise Error, "Failed to run #{command_name} task:\n#{run_task_response.pretty_inspect}"
          end

          task_arn = run_task_response.tasks[0].task_arn
          info "Launched #{command_name} task #{task_arn}, waiting for completion..."

          EcsManager.ecs.wait_until(:tasks_stopped, { cluster: @target.cluster, tasks: [task_arn] }) do |w|
            w.max_attempts = nil
            w.delay = Broadside.config.ecs.poll_frequency
            w.before_attempt do |attempt|
              debug "Attempt #{attempt}: waiting for #{command_name} to complete..."
            end
          end

          info "#{command_name} task container logs:\n#{get_container_logs(task_arn)}"

          if (code = EcsManager.get_task_exit_code(@target.cluster, task_arn, @target.family)) == 0
            info "#{command_name} task #{task_arn} complete"
          else
            raise Error, "#{command_name} task #{task_arn} exited with a non-zero status code #{code}!"
          end
        end
      ensure
        EcsManager.deregister_last_n_tasks_definitions(@target.family, 1)
      end
    end

    def get_container_logs(task_arn)
      ip = EcsManager.get_running_instance_ips!(@target.cluster, @target.family, task_arn).first
      debug "Found IP of container instance: #{ip}"

      find_container_id_cmd = "#{Broadside.config.ssh_cmd(ip)} \"docker ps -aqf 'label=com.amazonaws.ecs.task-arn=#{task_arn}'\""
      debug "Running command to find container id:\n#{find_container_id_cmd}"
      container_ids = `#{find_container_id_cmd}`.split

      logs = ''
      container_ids.each do |container_id|
        get_container_logs_cmd = "#{Broadside.config.ssh_cmd(ip)} \"docker logs #{container_id}\""
        debug "Running command to get logs of container #{container_id}:\n#{get_container_logs_cmd}"

        Open3.popen3(get_container_logs_cmd) do |_, stdout, stderr, _|
          logs << "STDOUT (#{container_id}):--\n#{stdout.read}\nSTDERR (#{container_id}):--\n#{stderr.read}\n"
        end
      end

      logs
    end

    def container_definition
      configured_containers = (@target.task_definition_config || {})[:container_definitions]

      if configured_containers && configured_containers.size > 1
        raise ArgumentError, 'Creating > 1 container definition not supported yet'
      end

      (configured_containers.try(:first) || {}).merge(
        name: @target.family,
        command: @command,
        environment: @target.env_vars,
        image: image_tag
      )
    end
  end
end
