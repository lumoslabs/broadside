require 'active_support/core_ext/hash'
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
        exception "Service #{family} does not exist!" unless EcsManager.service_exists?(config.ecs.cluster, family)
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
      unless EcsManager.get_latest_task_definition_arn(family)
        # TODO right now this creates a useless first revision and then update_task_revision will create a 2nd one
        raise ArgumentError, "No first task definition and cannot create one" unless @deploy_config.task_definition_config

        info "Creating an initial task definition for '#{family}' from the config..."

        EcsManager.create_task_definition(
          family,
          @deploy_config.command,
          @deploy_config.env_vars,
          image_tag,
          @deploy_config.task_definition_config
        )
      end

      unless EcsManager.service_exists?(config.ecs.cluster, family)
        raise ArgumentError, "Service doesn't exist and cannot be created" unless @deploy_config.service_config

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
          @deploy_config.predeploy_commands.each do |command|
            run_command(command)
          end
        ensure
          EcsManager.deregister_last_n_tasks_definitions(family, 1)
        end
      end
    end

    def status
      super do
        info "\n---------------",
          "\nDeployed task definition information:\n",
          Rainbow(PP.pp(EcsManager.get_latest_task_definition(family), '')).blue,
          "\nPrivate ips of instances running containers:\n",
          Rainbow(get_running_instance_ips.join(' ')).blue,
          "\n\nssh command:\n#{Rainbow(gen_ssh_cmd(ips.first)).cyan}",
          "\n---------------\n"
      end
    end

    def logtail
      super do
        ip = get_running_instance_ips.fetch(@deploy_config.instance)
        debug "Tailing logs for running container at ip #{ip}..."
        search_pattern = Shellwords.shellescape(family)
        cmd = "docker logs -f --tail=10 `docker ps -n 1 --quiet --filter name=#{search_pattern}`"
        tail_cmd = gen_ssh_cmd(ip) + " '#{cmd}'"
        exec tail_cmd
      end
    end

    def ssh
      super do
        ip = get_running_instance_ips.fetch(@deploy_config.instance)
        debug "Establishing an SSH connection to ip #{ip}..."
        exec gen_ssh_cmd(ip)
      end
    end

    def bash
      super do
        ip = get_running_instance_ips.fetch(@deploy_config.instance)
        debug "Running bash for running container at ip #{ip}..."
        search_pattern = Shellwords.shellescape(family)
        cmd = "docker exec -i -t `docker ps -n 1 --quiet --filter name=#{search_pattern}` bash"
        bash_cmd = gen_ssh_cmd(ip, tty: true) + " '#{cmd}'"
        exec bash_cmd
      end
    end

    private

    # creates a new task revision using current directory's env vars and provided tag
    def update_task_revision
      new_task_def = create_new_task_revision

      new_task_def[:container_definitions].select { |c| c[:name] == family }.first.tap do |container_def|
        container_def[:environment] = @deploy_config.env_vars
        container_def[:image] = image_tag
        container_def[:command] = @deploy_config.command
      end

      debug "Creating a new task definition..."
      arn = EcsManger.ecs.register_task_definition(new_task_def).task_definition.task_definition_arn
      debug "Successfully created #{arn}"
    end

    # reloads the service using the latest task definition
    def update_service
      task_definition_arn = EcsManager.get_latest_task_definition_arn(family)
      debug "Updating #{family} with scale=#{@deploy_config.scale} using task #{task_definition_arn}..."

      update_service_response = EcsManager.ecs.update_service(
        cluster: config.ecs.cluster,
        service: family,
        task_definition: task_definition_arn,
        desired_count: @deploy_config.scale
      )

      exception 'Failed to update service during deploy.' unless update_service_response.successful?

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
      run_task_response = EcsManager.ecs.run_task(config.ecs.cluster, family, command)

      exception "Failed to run #{command_name} task." unless run_task_response.successful?

      command_name = command.join(' ')
      task_arn = run_task_response.tasks[0].task_arn
      debug "Launched #{command_name} task #{task_arn}, waiting for completion..."

      EcsManager.ecs.wait_until(:tasks_stopped, { cluster: config.ecs.cluster, tasks: [task_arn] }) do |w|
        w.max_attempts = nil
        w.delay = config.ecs.poll_frequency
        w.before_attempt do |attempt|
          debug "Attempt #{attempt}: waiting for #{command_name} to complete..."
        end
      end

      debug 'Task finished running, getting logs...'
      info "#{command_name} task container logs:\n#{get_container_logs(task_arn)}"
      if (code = get_task_exit_code(task_arn, family)) == 0
        debug "#{command_name} task #{task_arn} exited with status code 0"
      else
        exception "#{command_name} task #{task_arn} exited with a non-zero status code #{code}!"
      end
    end

    def get_container_logs(task_arn)
      ip = get_running_instance_ips(task_arn).first
      debug "Found ip of container instance: #{ip}"

      find_container_id_cmd = "#{gen_ssh_cmd(ip)} \"docker ps -aqf 'label=com.amazonaws.ecs.task-arn=#{task_arn}'\""
      debug "Running command to find container id:\n#{find_container_id_cmd}"
      container_id = `#{find_container_id_cmd}`.strip

      get_container_logs_cmd = "#{gen_ssh_cmd(ip)} \"docker logs #{container_id}\""
      debug "Running command to get logs of container #{container_id}:",
        "\n#{get_container_logs_cmd}"

      logs = nil
      Open3.popen3(get_container_logs_cmd) do |_, stdout, stderr, _|
        logs = "STDOUT:--\n#{stdout.read}\nSTDERR:--\n#{stderr.read}"
      end
      logs
    end

    def get_running_instance_ips(task_ids = nil)
      task_arns = nil
      if task_ids.nil?
        task_arns = EcsManager.get_task_arns(config.ecs.cluster, family)
        if task_arns.empty?
          exception "No running tasks found for '#{family}' on cluster '#{config.ecs.cluster}' !"
        end
      elsif task_ids.class == String
        task_arns = [task_ids]
      else
        task_arns = task_ids
      end

      tasks = EcsManger.ecs.describe_tasks(cluster: config.ecs.cluster, tasks: task_arns).tasks
      container_instance_arns = tasks.map { |t| t.container_instance_arn }
      container_instances = EcsManger.ecs.describe_container_instances(
        cluster: config.ecs.cluster, container_instances: container_instance_arns
      ).container_instances
      ec2_instance_ids = container_instances.map { |ci| ci.ec2_instance_id }
      reservations = ec2_client.describe_instances({ instance_ids: ec2_instance_ids }).reservations
      instances = reservations.map { |r| r.instances }.flatten

      instances.map { |i| i.private_ip_address }
    end

    def create_new_task_revision
      task_def = EcsManager.get_latest_task_definition(family)
      task_def.delete(:task_definition_arn)
      task_def.delete(:requires_attributes)
      task_def.delete(:revision)
      task_def.delete(:status)
      task_def
    end

    def ec2_client
      @ec2_client ||= Aws::EC2::Client.new(
        region: config.aws.region,
        credentials: config.aws.credentials
      )
    end
  end
end
