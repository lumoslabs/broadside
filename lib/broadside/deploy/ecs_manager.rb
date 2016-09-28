module Broadside
  class EcsManager
    DEFAULT_DESIRED_COUNT = 0
    DEFAULT_CONTAINER_DEFINITION = {
      cpu: 1,
      essential: true,
      memory: 1000
    }

    class << self
      def ecs
        @ecs_client ||= Aws::ECS::Client.new(
          region: Broadside.config.aws.region,
          credentials: Broadside.config.aws.credentials
        )
      end

      def create_service(cluster, name, options = {})
        ecs.create_service(
          {
            cluster: cluster,
            desired_count: DEFAULT_DESIRED_COUNT,
            service_name: name,
            task_definition: name
          }.deep_merge(options)
        )
      end

      def create_task_definition(name, command, environment, image, options = {})
        # Deep merge doesn't work with arrays, so build the hash and merge later
        container = DEFAULT_CONTAINER_DEFINITION.merge(
          name: name,
          command: command,
          environment: environment,
          image: image,
        ).merge(options[:container_definitions].first || {})

        ecs.register_task_definition({ family: name }.deep_merge(options).merge(container_definitions: [container]))
      end

      def get_task_arns(cluster, family)
        all_results(:list_tasks, :task_arns, { cluster: cluster, family: family })
      end

      def get_task_definition_arns(family)
        all_results(:list_task_definitions, :task_definition_arns, { family_prefix: family })
      end

      def get_task_exit_code(task_arn, family)
        task = EcsManager.ecs.describe_tasks({ cluster: Broadside.config.ecs.cluster, tasks: [task_arn] }).tasks.first
        container = task.containers.select { |c| c.name == family }.first
        container.exit_code
      end

      def list_task_definition_families
        all_results(:list_task_definition_families, :families)
      end

      def list_services
        all_results(:list_services, :service_arns, { cluster: config.ecs.cluster })
      end

      def service_exists?(cluster, family)
        services = ecs.describe_services({ cluster: cluster, services: [family] })
        services.failures.empty? && !services.services.empty?
      end

      private

      def all_results(method, key, args = {})
        page = ecs.public_send(method, args)
        results = page.send(key)

        while page.next_token
          page = ecs.send(method, args.merge(next_token: page.next_token))
          results += page.send(key)
        end

        results
      end
    end
  end
end
