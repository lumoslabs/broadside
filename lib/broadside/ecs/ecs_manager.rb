module Broadside
  class EcsManager
    DEFAULT_DESIRED_COUNT = 0

    class << self
      include LoggingUtils

      def ecs
        @ecs_client ||= Aws::ECS::Client.new(
          region: Broadside.config.aws.region,
          credentials: Broadside.config.aws.credentials,
          logger: Broadside.config.logger,
          log_formatter: Aws::Log::Formatter.colored
        )
      end

      def create_service(cluster, name, service_config = {})
        ecs.create_service(
          {
            cluster: cluster,
            desired_count: DEFAULT_DESIRED_COUNT,
            service_name: name,
            task_definition: name
          }.deep_merge(service_config)
        )
      end

      # removes latest n task definitions
      def deregister_last_n_tasks_definitions(name, count)
        get_task_definition_arns(name).last(count).each do |arn|
          ecs.deregister_task_definition(task_definition: arn)
          debug "Deregistered #{arn}"
        end
      end

      def get_latest_task_definition(name)
        return nil unless (arn = get_latest_task_definition_arn(name))
        ecs.describe_task_definition(task_definition: arn).task_definition.to_h.reject {|k, _v| k == :registered_at || k == :registered_by }
      end

      def get_latest_task_definition_arn(name)
        get_task_definition_arns(name).last
      end

      def get_running_instance_ips!(cluster, family, task_arns = nil)
        ips = get_running_instance_ips(cluster, family, task_arns)
        raise Error, "No running tasks found for '#{family}' on cluster '#{cluster}'!" if ips.empty?
        ips
      end

      def get_running_instance_ips(cluster, family, task_arns = nil)
        task_arns = task_arns ? Array.wrap(task_arns) : get_task_arns(cluster, family)
        return [] if task_arns.empty?

        tasks = ecs.describe_tasks(cluster: cluster, tasks: task_arns).tasks
        container_instances = ecs.describe_container_instances(
          cluster: cluster,
          container_instances: tasks.map(&:container_instance_arn)
        ).container_instances

        ec2_instance_ids = container_instances.map(&:ec2_instance_id)
        reservations = ec2_client.describe_instances(instance_ids: ec2_instance_ids).reservations

        reservations.map(&:instances).flatten.map(&:private_ip_address)
      end

      def get_task_arns(cluster, family, filter = {})
        options = {
          cluster: cluster,
          # Strange AWS restriction requires absence of family if service_name specified
          family: filter[:service_name] ? nil : family,
          desired_status: filter[:desired_status],
          service_name: filter[:service_name],
          started_by: filter[:started_by]
        }.reject { |_, v| v.nil? }

        all_results(:list_tasks, :task_arns, options)
      end

      def get_task_definition_arns(family)
        all_results(:list_task_definitions, :task_definition_arns, { family_prefix: family })
      end

      def get_task_exit_status(cluster, task_arn, name)
        task = ecs.describe_tasks(cluster: cluster, tasks: [task_arn]).tasks.first
        container = task.containers.select { |c| c.name == name }.first

        {
          exit_code: container.exit_code,
          reason: container.reason
        }
      end

      def list_task_definition_families
        all_results(:list_task_definition_families, :families)
      end

      def list_services(cluster)
        all_results(:list_services, :service_arns, { cluster: cluster })
      end

      def run_task(cluster, name, command, options = {})
        raise ArgumentError, "command: '#{command}' must be an array" unless command.is_a?(Array)

        response = ecs.run_task(
          cluster: cluster,
          task_definition: get_latest_task_definition_arn(name),
          overrides: {
            container_overrides: [
              {
                name: name,
                command: command
              }
            ]
          },
          count: 1,
          started_by: ((options[:started_by] ? "#{options[:started_by]}:" : '') + command.join(' '))[0...36]
        )

        unless response.successful? && response.tasks.try(:[], 0)
          raise EcsError, "Failed to run task '#{command.join(' ')}'\n#{response.pretty_inspect}"
        end

        response
      end

      def service_exists?(cluster, family)
        services = ecs.describe_services(cluster: cluster, services: [family])
        services.failures.empty? && services.services.any?
      end

      def check_service_and_task_definition_state!(target)
        check_task_definition_state!(target)
        check_service_state!(target)
      end

      def check_task_definition_state!(target)
        unless get_latest_task_definition_arn(target.family)
          raise Error, "No task definition for '#{target.family}'! Please bootstrap or manually configure one."
        end
      end

      def check_service_state!(target)
        unless service_exists?(target.cluster, target.family)
          raise Error, "No service for '#{target.family}'! Please bootstrap or manually configure one."
        end
      end

      def current_service_scale(target)
        check_service_state!(target)
        EcsManager.ecs.describe_services(cluster: target.cluster, services: [target.family]).services.first[:desired_count]
      end

      private

      def all_results(method, key, args = {})
        page = ecs.public_send(method, args)
        results = page.public_send(key)

        while page.next_token
          page = ecs.public_send(method, args.merge(next_token: page.next_token))
          results += page.public_send(key)
        end

        results
      end

      def ec2_client
        @ec2_client ||= Aws::EC2::Client.new(
          region: Broadside.config.aws.region,
          credentials: Broadside.config.aws.credentials,
          logger: Broadside.config.logger,
          log_formatter: Aws::Log::Formatter.colored
        )
      end
    end
  end
end
