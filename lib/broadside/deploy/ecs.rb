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
      check_service_existence
    end

    def deploy
      super do
        update_task

        begin
          update_service
        rescue SignalException::Interrupt
          error 'Caught interrupt signal, rolling back...'
          rollback(1)
          error 'Deployment did not finish successfully.'
          abort
        rescue StandardError => e
          error e.inspect, "\n", e.backtrace.join("\n")
          error 'Deploy failed! Rolling back...'
          rollback(1)
          error 'Deployment did not finish successfully.'
          abort
        end
      end
    end

    def rollback(count = @deploy_config.rollback)
      super do
        begin
          deregister_tasks(count)
          update_service
        rescue StandardError => e
          error 'Rollback failed to complete!'
          raise e
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
        update_task

        begin
          run_command(@deploy_config.command)
        ensure
          deregister_tasks(1)
        end
      end
    end

    # runs before deploy commands using the latest task definition
    def run_predeploy
      super do
        update_task

        begin
          @deploy_config.predeploy_commands.each do |command|
            run_command(command)
          end
        ensure
          deregister_tasks(1)
        end
      end
    end

    def status
      super do
        td = get_latest_task_def
        ips = get_running_instance_ips
        info "\n---------------",
          "\nDeployed task definition information:\n",
          Rainbow(PP.pp(td, '')).blue,
          "\nPrivate ips of instances running containers:\n",
          Rainbow(ips.join(' ')).blue,
          "\n\nssh command:\n#{Rainbow(gen_ssh_cmd(ips.first)).cyan}",
          "\n---------------\n"
      end
    end

    def logtail
      super do
        ip = get_running_instance_ip_at_index!(@deploy_config.instance)
        debug "Tailing logs for running container at ip #{ip}..."
        search_pattern = Shellwords.shellescape(family)
        cmd = "docker logs -f --tail=10 `docker ps -n 1 --quiet --filter name=#{search_pattern}`"
        tail_cmd = gen_ssh_cmd(ip) + " '#{cmd}'"
        exec tail_cmd
      end
    end

    def ssh
      super do
        ip = get_running_instance_ip_at_index!(@deploy_config.instance)
        debug "Establishing an SSH connection to ip #{ip}..."
        exec gen_ssh_cmd(ip)
      end
    end

    def bash
      super do
        ip = get_running_instance_ip_at_index!(@deploy_config.instance)
        debug "Running bash for running container at ip #{ip}..."
        search_pattern = Shellwords.shellescape(family)
        cmd = "docker exec -i -t `docker ps -n 1 --quiet --filter name=#{search_pattern}` bash"
        bash_cmd = gen_ssh_cmd(ip, tty: true) + " '#{cmd}'"
        exec bash_cmd
      end
    end

    private

    def get_running_instance_ip_at_index(index)
      ips = get_running_instance_ips
      ips.size > index ? ips[index] : false
    end

    def get_running_instance_ip_at_index!(index)
      ip = get_running_instance_ip_at_index(index)
      return ip if ip
      exception 'Instance index greater than available instance count.'
    end

    # removes latest n task definitions
    def deregister_tasks(count)
      get_task_def_ids.last(count).each do |td_id|
        ecs_client.deregister_task_definition({task_definition: td_id})
        debug "Deregistered #{td_id}"
      end
    end

    # creates a new task revision using current directory's env vars and provided tag
    def update_task
      debug "Creating a new task definition..."
      new_task_def = create_new_task_revision

      #TODO instead of first, use select to cover task defs w multiple containers
      new_task_def[:container_definitions].first[:environment] = @deploy_config.env_vars
      new_task_def[:container_definitions].first[:image] = image_tag
      new_task_def[:container_definitions].first[:command] = @deploy_config.command
      new_task_def_id = ecs_client.register_task_definition(new_task_def).task_definition.task_definition_arn
      debug "Successfully created #{new_task_def_id}"
    end

    # reloads the service using the latest task definition
    def update_service
      td = get_latest_task_def_id
      debug "Updating #{family} with scale=#{@deploy_config.scale} using task #{td}..."
      resp =  ecs_client.update_service({
        cluster: config.ecs.cluster,
        service: family,
        task_definition: get_latest_task_def_id,
        desired_count: @deploy_config.scale
      })
      if resp.successful?
        begin
          ecs_client.wait_until(:services_stable, {cluster: config.ecs.cluster, services: [family]}) do |w|
            w.max_attempts = @deploy_config.timeout.nil? ? @deploy_config.timeout : @deploy_config.timeout / config.ecs.poll_frequency
            w.delay = config.ecs.poll_frequency
            seen_event = nil
            w.before_wait do |attempt, response|
              debug "(#{attempt}/#{w.max_attempts}) Polling ECS for events..."
              # skip first event since it doesn't apply to current request
              if response.services[0].events.first &&
                  response.services[0].events.first.id != seen_event &&
                  attempt > 1
                seen_event = response.services[0].events.first.id
                debug(response.services[0].events.first.message)
              end
            end
          end
        rescue Aws::Waiters::Errors::TooManyAttemptsError
          exception 'Deploy did not finish in the expected amount of time.'
        end
      else
        exception 'Failed to update service during deploy.'
      end
    end

    def run_command(command)
      command_name = command.join(' ')
      resp = ecs_client.run_task({
        cluster: config.ecs.cluster,
        task_definition: get_latest_task_def_id,
        overrides: {
          container_overrides: [
            {
              name: family,
              command: command
            },
          ],
        },
        count: 1,
        started_by: "before_deploy:#{command_name}"[0...36]
      })
      if resp.successful?
        task_id = resp.tasks[0].task_arn
        debug "Launched #{command_name} task #{task_id}"
        debug "Waiting for #{command_name} to complete..."
        ecs_client.wait_until(:tasks_stopped, {cluster: config.ecs.cluster, tasks: [task_id]}) do |w|
          w.max_attempts = nil
          w.delay = config.ecs.poll_frequency
          w.before_attempt do |attempt|
            debug "Attempt #{attempt}: waiting for #{command_name} to complete..."
          end
        end
        debug 'Task finished running, getting logs...'
        info "#{command_name} task container logs:\n#{get_container_logs(task_id)}"
        if(code = get_task_exit_code(task_id)) == 0
          debug "#{command_name} task #{task_id} exited with status code 0"
        else
          exception "#{command_name} task #{task_id} exited with a non-zero status code #{code}!"
        end
      else
        raise "Failed to run #{command_name} task."
      end
    end

    def get_container_logs(task_id)
      ip = get_running_instance_ips(task_id).first
      debug "Found ip of container instance: #{ip}"

      find_container_id_cmd = "#{gen_ssh_cmd(ip)} \"docker ps -aqf 'label=com.amazonaws.ecs.task-arn=#{task_id}'\""
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

    def get_task_exit_code(task_id)
      task = ecs_client.describe_tasks({cluster: config.ecs.cluster, tasks: [task_id]}).tasks.first
      task.containers.first.exit_code
    end

    def get_running_instance_ips(task_ids = nil)
      task_arns = nil
      if task_ids.nil?
        task_arns = get_tasks
        if task_arns.empty?
          exception "No running tasks found for '#{family}' on cluster '#{config.ecs.cluster}' !"
        end
      elsif task_ids.class == String
        task_arns = [task_ids]
      else
        task_arns = task_ids
      end

      tasks = ecs_client.describe_tasks({cluster: config.ecs.cluster, tasks: task_arns}).tasks
      container_instance_arns = tasks.map { |t| t.container_instance_arn }
      container_instances = ecs_client.describe_container_instances({
        cluster: config.ecs.cluster, container_instances: container_instance_arns
      }).container_instances
      ec2_instance_ids = container_instances.map { |ci| ci.ec2_instance_id }
      reservations = ec2_client.describe_instances({instance_ids: ec2_instance_ids}).reservations
      instances = reservations.map { |r| r.instances }.flatten
      private_ips = instances.map { |i| i.private_ip_address }
      private_ips
    end

    def get_latest_task_def
      ecs_client.describe_task_definition({task_definition: get_latest_task_def_id}).task_definition.to_h
    end

    def get_tasks
      # used for pagination if > 100 tasks
      next_token = nil
      tasks = []
      loop do
        resp = ecs_client.list_tasks({cluster: config.ecs.cluster, family: family, next_token: next_token})
        next_token = resp.next_token
        tasks += resp.task_arns
        break if next_token.nil?
      end

      tasks
    end

    def get_task_def_ids
      # used for pagination if > 100 task_definition ids
      next_token = nil
      task_def_ids = []
      loop do
        resp = ecs_client.list_task_definitions({family_prefix: family, next_token: next_token})
        next_token = resp.next_token
        task_def_ids += resp.task_definition_arns
        break if next_token.nil?
      end

      task_def_ids
    end

    def get_latest_task_def_id
      get_task_def_ids.last
    end

    def create_new_task_revision
      task_def = get_latest_task_def
      task_def.delete(:task_definition_arn)
      task_def.delete(:requires_attributes)
      task_def.delete(:revision)
      task_def.delete(:status)
      task_def
    end

    def ecs_client
      @ecs_client ||= Aws::ECS::Client.new({
        region: config.aws.region,
        credentials: config.aws.credentials
      })
    end

    def ec2_client
      @ec2_client ||= Aws::EC2::Client.new({
        region: config.aws.region,
        credentials: config.aws.credentials
      })
    end

    def check_service_existence
      resp = ecs_client.describe_services({cluster: config.ecs.cluster, services: [family]})
      unless resp.failures.empty?
        exception "Could not find ECS service '#{family}' in cluster '#{config.ecs.cluster}' !"
      end
    end
  end
end
