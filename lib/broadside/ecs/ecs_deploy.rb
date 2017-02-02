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
      super
      Broadside.config.ecs.verify(:poll_frequency)
    end

    def deploy
      super do
        unless EcsManager.service_exists?(@target.cluster, family)
          raise Error, "No service for '#{family}'! Please bootstrap or manually configure one."
        end
        unless EcsManager.get_latest_task_definition_arn(family)
          raise Error, "No task definition for '#{family}'! Please bootstrap or manually configure one."
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
      if EcsManager.get_latest_task_definition_arn(family)
        info("Task definition for #{family} already exists.")
      else
        unless @target.task_definition_config
          raise ArgumentError, "No first task definition and no :task_definition_config in '#{family}' configuration"
        end

        info "Creating an initial task definition for '#{family}' from the config..."

        EcsManager.ecs.register_task_definition(
          @target.task_definition_config.merge(
            family: family,
            container_definitions: [DEFAULT_CONTAINER_DEFINITION.merge(container_definition)]
          )
        )
      end

      run_commands(@target.bootstrap_commands)

      if EcsManager.service_exists?(@target.cluster, family)
        info("Service for #{family} already exists.")
      else
        unless @target.service_config
          raise ArgumentError, "Service doesn't exist and no :service_config in '#{family}' configuration"
        end

        info "Service '#{family}' doesn't exist, creating..."
        EcsManager.create_service(@target.cluster, family, @target.service_config)
      end
    end

    def rollback(count = 1)
      super do
        begin
          EcsManager.deregister_last_n_tasks_definitions(family, count)
          update_service
        rescue StandardError
          error 'Rollback failed to complete!'
          raise
        end
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
        search_pattern = Shellwords.shellescape(family)
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
        search_pattern = Shellwords.shellescape(family)
        cmd = "docker exec -i -t `docker ps -n 1 --quiet --filter name=#{search_pattern}` bash"
        exec(Broadside.config.ssh_cmd(ip, tty: true) + " '#{cmd}'")
      end
    end

    # reloads the service using the latest task definition
    def update_service(options = {})
      scale = options[:scale] || @target.scale
      raise ArgumentError, ':scale not provided' unless scale

      task_definition_arn = EcsManager.get_latest_task_definition_arn(family)
      debug "Updating #{family} with scale=#{scale} using task_definition #{task_definition_arn}..."

      update_service_response = EcsManager.ecs.update_service({
        cluster: @target.cluster,
        desired_count: scale,
        service: family,
        task_definition: task_definition_arn
      }.deep_merge(@target.service_config || {}))

      unless update_service_response.successful?
        raise Error, "Failed to update service during deploy:\n#{update_service_response.pretty_inspect}"
      end

      EcsManager.ecs.wait_until(:services_stable, cluster: @target.cluster, services: [family]) do |w|
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

    private

    def get_running_instance_ip!
      ips = EcsManager.get_running_instance_ips!(@target.cluster, family)
      ips.fetch(@instance)
    end

    # Creates a new task revision using current directory's env vars, provided tag, and configured options.
    # Currently can only handle a single container definition.
    def update_task_revision
      revision = EcsManager.get_latest_task_definition(family).except(
        :requires_attributes,
        :revision,
        :status,
        :task_definition_arn
      )
      updatable_container_definitions = revision[:container_definitions].select { |c| c[:name] == family }
      raise Error, "Can only update one container definition!" if updatable_container_definitions.size != 1

      # Deep merge doesn't work well with arrays (e.g. container_definitions), so build the container first.
      updatable_container_definitions.first.merge!(container_definition)
      revision.deep_merge!((@target.task_definition_config || {}).except(:container_definitions))

      task_definition = EcsManager.ecs.register_task_definition(revision).task_definition
      debug "Successfully created #{task_definition.task_definition_arn}"
    end

    def run_commands(commands)
      return if commands.nil? || commands.empty?
      Broadside.config.verify(:ssh)
      update_task_revision

      begin
        Array.wrap(commands).each do |command|
          command_name = command.join(' ')
          run_task_response = EcsManager.run_task(@target.cluster, family, command)

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

          exit_code = EcsManager.get_task_exit_code(@target.cluster, task_arn, family)
          raise Error, "#{command_name} task #{task_arn} exited with a non-zero status code #{exit_code}!" if exit_code.zero?

          info "#{command_name} task #{task_arn} complete"
        end
      ensure
        EcsManager.deregister_last_n_tasks_definitions(family, 1)
      end
    end

    def get_container_logs(task_arn)
      ip = EcsManager.get_running_instance_ips!(@target.cluster, family, task_arn).first
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
        name: family,
        command: @command,
        environment: @target.env_vars,
        image: image_tag
      )
    end
  end
end
