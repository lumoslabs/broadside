require 'open3'

module Broadside
  class EcsDeploy < Deploy
    delegate :cluster, to: :target
    delegate :family, to: :target

    DEFAULT_CONTAINER_DEFINITION = {
      cpu: 1,
      essential: true,
      memory: 1024
    }

    def short
      deploy
    end

    def full
      info "Running predeploy commands for #{family}..."
      run_commands(@target.predeploy_commands, started_by: 'predeploy')
      info 'Predeploy complete.'

      deploy
    end

    def bootstrap
      if EcsManager.get_latest_task_definition_arn(family)
        info "Task definition for #{family} already exists."
      else
        raise ConfigurationError, "No :task_definition_config for #{family}" unless @target.task_definition_config
        info "Creating an initial task definition for '#{family}' from the config..."

        EcsManager.ecs.register_task_definition(
          @target.task_definition_config.merge(
            family: family,
            container_definitions: [DEFAULT_CONTAINER_DEFINITION.merge(configured_container_definition)]
          )
        )
      end

      run_commands(@target.bootstrap_commands, started_by: 'bootstrap')

      if EcsManager.service_exists?(cluster, family)
        info("Service for #{family} already exists.")

        # Verify that the requested ELB config matches what is running.
        if @target.load_balancer_config && (elb_arn = EcsManager.get_load_balancer_arn_by_name(family))
          elb = elb_client.describe_load_balancers(load_balancer_arns: [elb_arn]).load_balancers.first.to_h

          @target.load_balancer_config.each do |k, v|
            raise Error, "Running ELB.#{k} is '#{elb[k]}'; config says #{v}. Can't reconfigure." if elb[k] != v
          end
        end
      else
        raise ConfigurationError, "No :service_config for #{family}" unless @target.service_config
        info "Service '#{family}' doesn't exist, creating..."

        if @target.load_balancer_config
          EcsManager.create_load_balancer(@target.load_balancer_config.merge(name: family))
          EcsManager.create_service(cluster, family, @target.service_config.merge(load_balancers: [load_balancer_name: family]))
        else
          EcsManager.create_service(cluster, family, @target.service_config)
        end
      end
    end

    def rollback(options = {})
      count = options[:rollback] || 1
      info "Rolling back #{count} release(s) for #{family}..."
      EcsManager.check_service_and_task_definition_state!(@target)

      begin
        EcsManager.deregister_last_n_tasks_definitions(family, count)
        update_service(options)
      rescue StandardError
        error 'Rollback failed to complete!'
        raise
      end

      info 'Rollback complete.'
    end

    def scale(options = {})
      info "Rescaling #{family} with scale=#{@scale}..."
      update_service(options)
      info 'Rescaling complete.'
    end

    def run_commands(commands, options = {})
      return if commands.nil? || commands.empty?
      update_task_revision

      begin
        commands.each do |command|
          command_name = "'#{command.join(' ')}'"
          task_arn = EcsManager.run_task(cluster, family, command, options).tasks[0].task_arn
          info "Launched #{command_name} task #{task_arn}, waiting for completion..."

          EcsManager.ecs.wait_until(:tasks_stopped, cluster: cluster, tasks: [task_arn]) do |w|
            w.max_attempts = nil
            w.delay = Broadside.config.aws.ecs_poll_frequency
            w.before_attempt do |attempt|
              info "Attempt #{attempt}: waiting for #{command_name} to complete..."
            end
          end

          exit_status = EcsManager.get_task_exit_status(cluster, task_arn, family)
          raise EcsError, "#{command_name} failed to start:\n'#{exit_status[:reason]}'" if exit_status[:exit_code].nil?
          raise EcsError, "#{command_name} nonzero exit code: #{exit_status[:exit_code]}!" unless exit_status[:exit_code].zero?

          info "#{command_name} task container logs:\n#{get_container_logs(task_arn)}"
          info "#{command_name} task #{task_arn} complete"
        end
      ensure
        EcsManager.deregister_last_n_tasks_definitions(family, 1)
      end
    end

    private

    def deploy
      current_scale = EcsManager.current_service_scale(@target)
      update_task_revision

      begin
        update_service
      rescue Interrupt, StandardError => e
        msg = e.is_a?(Interrupt) ? 'Caught interrupt signal' : "#{e.class}: #{e.message}"
        error "#{msg}, rolling back..."
        # In case of failure during deploy, rollback to the previously configured scale
        rollback(scale: current_scale)
        error 'Deployment did not finish successfully.'
        raise e
      end
    end

    # Creates a new task revision using current directory's env vars, provided tag, and @target.task_definition_config
    def update_task_revision
      EcsManager.check_task_definition_state!(target)
      revision = EcsManager.get_latest_task_definition(family).except(
        :requires_attributes,
        :revision,
        :status,
        :task_definition_arn
      )
      updatable_container_definitions = revision[:container_definitions].select { |c| c[:name] == family }
      raise Error, 'Can only update one container definition!' if updatable_container_definitions.size != 1

      # Deep merge doesn't work well with arrays (e.g. container_definitions), so build the container first.
      updatable_container_definitions.first.merge!(configured_container_definition)
      revision.deep_merge!((@target.task_definition_config || {}).except(:container_definitions))

      task_definition = EcsManager.ecs.register_task_definition(revision).task_definition
      debug "Successfully created #{task_definition.task_definition_arn}"
    end

    def update_service(options = {})
      scale = options[:scale] || @target.scale
      raise ArgumentError, ':scale not provided' unless scale

      EcsManager.check_service_and_task_definition_state!(target)
      task_definition_arn = EcsManager.get_latest_task_definition_arn(family)
      debug "Updating #{family} with scale=#{scale} using task_definition #{task_definition_arn}..."

      update_service_response = EcsManager.ecs.update_service({
        cluster: cluster,
        desired_count: scale,
        service: family,
        task_definition: task_definition_arn
      }.deep_merge(@target.service_config || {}))

      unless update_service_response.successful?
        raise EcsError, "Failed to update service:\n#{update_service_response.pretty_inspect}"
      end

      EcsManager.ecs.wait_until(:services_stable, cluster: cluster, services: [family]) do |w|
        timeout = Broadside.config.timeout
        w.delay = Broadside.config.aws.ecs_poll_frequency
        w.max_attempts = timeout ? timeout / w.delay : nil
        seen_event_id = nil

        w.before_wait do |attempt, response|
          info "(#{attempt}/#{w.max_attempts || Float::INFINITY}) Polling ECS for events..."
          # Skip first event since it doesn't apply to current request
          if response.services[0].events.first && response.services[0].events.first.id != seen_event_id && attempt > 1
            seen_event_id = response.services[0].events.first.id
            info response.services[0].events.first.message
          end
        end
      end
    end

    def get_container_logs(task_arn)
      ip = EcsManager.get_running_instance_ips!(cluster, family, task_arn).first
      debug "Found IP of container instance: #{ip}"

      find_container_id_cmd = "#{Broadside.config.ssh_cmd(ip)} \"docker ps -aqf 'label=com.amazonaws.ecs.task-arn=#{task_arn}'\""
      debug "Running command to find container id:\n#{find_container_id_cmd}"
      container_ids = `#{find_container_id_cmd}`.split

      logs = ''
      container_ids.each do |container_id|
        get_container_logs_cmd = "#{Broadside.config.ssh_cmd(ip)} \"docker logs #{container_id}\""
        debug "Running command to get logs of container #{container_id}:\n#{get_container_logs_cmd}"

        Open3.popen3(get_container_logs_cmd) do |_, stdout, stderr, _|
          logs << "STDOUT (#{container_id}):\n--\n#{stdout.read}\nSTDERR (#{container_id}):\n--\n#{stderr.read}\n"
        end
      end

      logs
    end

    def configured_container_definition
      (@target.task_definition_config.try(:[], :container_definitions).try(:first) || {}).merge(
        name: family,
        command: @target.command,
        environment: @target.ecs_env_vars,
        image: image_tag
      )
    end
  end
end
