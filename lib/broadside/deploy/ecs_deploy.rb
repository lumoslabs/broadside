require 'aws-sdk'
require 'open3'
require 'pp'
require 'rainbow'
require 'shellwords'

module Broadside
  class EcsDeploy < Deploy
    DEFAULT_CONTAINER_DEFINITION = {
      cpu: 1,
      essential: true,
      memory: 1000
    }

    def initialize(opts)
      super(opts)
    end

    def deploy
      super do
        unless EcsManager.service_exists?(@deploy_config.cluster, family)
          exception "No service for #{family}! Please bootstrap or manually configure the service."
        end
        unless EcsManager.get_latest_task_definition_arn(family)
          exception "No task definition for '#{family}'! Please bootstrap or manually configure the task definition."
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
        run_bootstrap_commands
      else
        unless @deploy_config.task_definition_config
          raise ArgumentError, "No first task definition and no :task_definition_config in '#{family}' configuration"
        end

        info "Creating an initial task definition for '#{family}' from the config..."

        EcsManager.ecs.register_task_definition(
          @deploy_config.task_definition_config.merge(
            family: family,
            container_definitions: [DEFAULT_CONTAINER_DEFINITION.merge(container_definition)]
          )
        )

        run_bootstrap_commands
      end

      if EcsManager.service_exists?(@deploy_config.cluster, family)
        info("Service for #{family} already exists.")
      else
        unless @deploy_config.service_config
          raise ArgumentError, "Service doesn't exist and no :service_config in '#{family}' configuration"
        end

        info "Service '#{family}' doesn't exist, creating..."
        EcsManager.create_service(@deploy_config.cluster, family, @deploy_config.service_config)
      end
    end

    def run_bootstrap_commands
      update_task_revision

      begin
        @deploy_config.bootstrap_commands.each { |command| run_command(command) }
      ensure
        EcsManager.deregister_last_n_tasks_definitions(family, 1)
      end
    end

    def rollback(count = @deploy_config.rollback)
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

    def scale
      super do
        update_service
      end
    end

    def run
      super do
        update_task_revision

        begin
          run_command(@deploy_config.command)
        ensure
          EcsManager.deregister_last_n_tasks_definitions(family, 1)
        end
      end
    end

    # runs before deploy commands using the latest task definition
    def run_predeploy
      super do
        update_task_revision

        begin
          @deploy_config.predeploy_commands.each { |command| run_command(command) }
        ensure
          EcsManager.deregister_last_n_tasks_definitions(family, 1)
        end
      end
    end

    def status
      super do
        ips = EcsManager.get_running_instance_ips(@deploy_config.cluster, family)
        info "\n---------------",
          "\nDeployed task definition information:\n",
          Rainbow(PP.pp(EcsManager.get_latest_task_definition(family), '')).blue,
          "\nPrivate ips of instances running containers:\n",
          Rainbow(ips.join(' ')).blue,
          "\n\nssh command:\n#{Rainbow(gen_ssh_cmd(ips.first)).cyan}",
          "\n---------------\n"
      end
    end

    def logtail
      super do
        ip = get_running_instance_ip
        debug "Tailing logs for running container at ip #{ip}..."
        search_pattern = Shellwords.shellescape(family)
        cmd = "docker logs -f --tail=#{@deploy_config.lines} `docker ps -n 1 --quiet --filter name=#{search_pattern}`"
        tail_cmd = gen_ssh_cmd(ip) + " '#{cmd}'"
        exec tail_cmd
      end
    end

    def ssh
      super do
        ip = get_running_instance_ip
        debug "Establishing an SSH connection to ip #{ip}..."
        exec gen_ssh_cmd(ip)
      end
    end

    def bash
      super do
        ip = get_running_instance_ip
        debug "Running bash for running container at ip #{ip}..."
        search_pattern = Shellwords.shellescape(family)
        cmd = "docker exec -i -t `docker ps -n 1 --quiet --filter name=#{search_pattern}` bash"
        bash_cmd = gen_ssh_cmd(ip, tty: true) + " '#{cmd}'"
        exec bash_cmd
      end
    end

    private

    def get_running_instance_ip
      EcsManager.get_running_instance_ips(@deploy_config.cluster, family).fetch(@deploy_config.instance)
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
      exception "Can only update one container definition!" if updatable_container_definitions.size != 1

      # Deep merge doesn't work well with arrays (e.g. :container_definitions), so build the container first.
      updatable_container_definitions.first.merge!(container_definition)
      revision.deep_merge!((@deploy_config.task_definition_config || {}).except(:container_definitions))

      task_definition = EcsManager.ecs.register_task_definition(revision).task_definition
      debug "Successfully created #{task_definition.task_definition_arn}"
    end

    # reloads the service using the latest task definition
    def update_service
      task_definition_arn = EcsManager.get_latest_task_definition_arn(family)
      debug "Updating #{family} with scale=#{@deploy_config.scale} using task #{task_definition_arn}..."

      update_service_response = EcsManager.ecs.update_service({
        cluster: @deploy_config.cluster,
        desired_count: @deploy_config.scale,
        service: family,
        task_definition: task_definition_arn
      }.deep_merge(@deploy_config.service_config || {}))

      unless update_service_response.successful?
        exception('Failed to update service during deploy.', update_service_response.pretty_inspect)
      end

      EcsManager.ecs.wait_until(:services_stable, { cluster: @deploy_config.cluster, services: [family] }) do |w|
        w.max_attempts = @deploy_config.timeout ? @deploy_config.timeout / @deploy_config.poll_frequency : nil
        w.delay = @deploy_config.poll_frequency
        seen_event = nil

        w.before_wait do |attempt, response|
          debug "(#{attempt}/#{w.max_attempts}) Polling ECS for events..."
          # skip first event since it doesn't apply to current request
          if response.services[0].events.first && response.services[0].events.first.id != seen_event && attempt > 1
            seen_event = response.services[0].events.first.id
            debug(response.services[0].events.first.message)
          end
        end
      end
    end

    def run_command(command)
      command_name = command.join(' ')
      run_task_response = EcsManager.run_task(@deploy_config.cluster, family, command)

      unless run_task_response.successful? && run_task_response.tasks.try(:[], 0)
        exception("Failed to run #{command_name} task.", run_task_response.pretty_inspect)
      end

      task_arn = run_task_response.tasks[0].task_arn
      debug "Launched #{command_name} task #{task_arn}, waiting for completion..."

      EcsManager.ecs.wait_until(:tasks_stopped, { cluster: @deploy_config.cluster, tasks: [task_arn] }) do |w|
        w.max_attempts = nil
        w.delay = config.ecs.poll_frequency
        w.before_attempt do |attempt|
          debug "Attempt #{attempt}: waiting for #{command_name} to complete..."
        end
      end

      info "#{command_name} task container logs:\n#{get_container_logs(task_arn)}"

      if (code = EcsManager.get_task_exit_code(@deploy_config.cluster, task_arn, family)) == 0
        debug "#{command_name} task #{task_arn} exited with status code 0"
      else
        exception "#{command_name} task #{task_arn} exited with a non-zero status code #{code}!"
      end
    end

    def get_container_logs(task_arn)
      ip = EcsManager.get_running_instance_ips(@deploy_config.cluster, family, task_arn).first
      debug "Found ip of container instance: #{ip}"

      find_container_id_cmd = "#{gen_ssh_cmd(ip)} \"docker ps -aqf 'label=com.amazonaws.ecs.task-arn=#{task_arn}'\""
      debug "Running command to find container id:\n#{find_container_id_cmd}"
      container_id = `#{find_container_id_cmd}`.strip

      get_container_logs_cmd = "#{gen_ssh_cmd(ip)} \"docker logs #{container_id}\""
      debug "Running command to get logs of container #{container_id}:\n#{get_container_logs_cmd}"

      logs = nil
      Open3.popen3(get_container_logs_cmd) do |_, stdout, stderr, _|
        logs = "STDOUT:--\n#{stdout.read}\nSTDERR:--\n#{stderr.read}"
      end
      logs
    end

    def container_definition
      configured_containers = (@deploy_config.task_definition_config || {})[:container_definitions]
      if configured_containers && configured_containers.size > 1
        raise ArgumentError, 'Creating > 1 container definition not supported yet'
      end

      (configured_containers.try(:first) || {}).merge(
        name: family,
        command: @deploy_config.command,
        environment: @deploy_config.env_vars,
        image: image_tag
      )
    end
  end
end
