require 'aws-sdk'
require 'open3'
require 'pp'
require 'rainbow'
require 'shellwords'

module Broadside
  class EcsDeploy < Deploy
    def initialize(opts)
      super(opts)
      config.ecs.verify(:cluster, :poll_frequency)
    end

    def deploy
      super do
        unless EcsManager.service_exists?(config.ecs.cluster, family)
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
        logger.info("Task definition for #{family} already exists.")
      else
        unless @deploy_config.task_definition_config
          raise ArgumentError, "No first task definition and no :task_definition_config in '#{family}' configuration"
        end

        info "Creating an initial task definition for '#{family}' from the config..."

        EcsManager.create_task_definition(
          family,
          @deploy_config.command,
          @deploy_config.env_vars,
          image_tag,
          @deploy_config.task_definition_config
        )
      end

      if EcsManager.service_exists?(config.ecs.cluster, family)
        logger.info("Service for #{family} already exists.")
      else
        unless @deploy_config.service_config
          raise ArgumentError, "Service doesn't exist and no :service_config in '#{family}' configuration"
        end

        info "Service '#{family}' doesn't exist, creating..."
        EcsManager.create_service(config.ecs.cluster, family, @deploy_config.service_config)
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
        ips = EcsManager.get_running_instance_ips(config.ecs.cluster, family)
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
        cmd = "docker logs -f --tail=10 `docker ps -n 1 --quiet --filter name=#{search_pattern}`"
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
      EcsManager.get_running_instance_ips(config.ecs.cluster, family).fetch(@deploy_config.instance)
    end

    # Creates a new task revision using current directory's env vars, provided tag, and configured options.
    # Currently can only handle a single container definition.
    def update_task_revision
      revision = EcsManager.get_latest_task_definition(family).except(
        :task_definition_arn,
        :requires_attributes,
        :revision,
        :status
      )
      revision.except!()

      debug "Creating a new task definition..."
      arn = EcsManager.create_task_definition(
        family,
        @deploy_config.command,
        @deploy_config.env_vars,
        image_tag,
        revision.deep_merge(@deploy_config.task_definition_config || {})
      ).task_definition.task_definition_arn
      debug "Successfully created #{arn}"
    end

    # reloads the service using the latest task definition
    def update_service
      task_definition_arn = EcsManager.get_latest_task_definition_arn(family)
      debug "Updating #{family} with scale=#{@deploy_config.scale} using task #{task_definition_arn}..."

      update_service_response = EcsManager.ecs.update_service({
        cluster: config.ecs.cluster,
        desired_count: @deploy_config.scale,
        service: family,
        task_definition: task_definition_arn
      }.deep_merge(@deploy_config.service_config || {}))

      unless update_service_response.successful?
        exception('Failed to update service during deploy.', update_service_response.pretty_inspect)
      end

      EcsManager.ecs.wait_until(:services_stable, { cluster: config.ecs.cluster, services: [family] }) do |w|
        w.max_attempts = @deploy_config.timeout ? @deploy_config.timeout / config.ecs.poll_frequency : nil
        w.delay = config.ecs.poll_frequency
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
      run_task_response = EcsManager.run_task(config.ecs.cluster, family, command)

      unless run_task_response.successful?
        exception("Failed to run #{command_name} task.", run_task_response.pretty_inspect)
      end

      task_arn = run_task_response.tasks[0].task_arn
      debug "Launched #{command_name} task #{task_arn}, waiting for completion..."

      EcsManager.ecs.wait_until(:tasks_stopped, { cluster: config.ecs.cluster, tasks: [task_arn] }) do |w|
        w.max_attempts = nil
        w.delay = config.ecs.poll_frequency
        w.before_attempt do |attempt|
          debug "Attempt #{attempt}: waiting for #{command_name} to complete..."
        end
      end

      info "#{command_name} task container logs:\n#{get_container_logs(task_arn)}"

      if (code = EcsManager.get_task_exit_code(config.ecs.cluster, task_arn, family)) == 0
        debug "#{command_name} task #{task_arn} exited with status code 0"
      else
        exception "#{command_name} task #{task_arn} exited with a non-zero status code #{code}!"
      end
    end

    def get_container_logs(task_arn)
      ip = EcsManager.get_running_instance_ips(config.ecs.cluster, family, task_arn).first
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
  end
end