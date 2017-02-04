require 'pp'
require 'tty-table'

module Broadside
  module Command
    extend LoggingUtils

    class << self
      def bootstrap(options)
        EcsDeploy.new(options[:target], options).bootstrap
      end

      def targets(options)
        table_header = nil
        table_rows = []

        Broadside.config.targets.each do |_, target|
          task_def = Broadside::EcsManager.get_latest_task_definition(target.family)
          service_tasks_running = Broadside::EcsManager.get_task_arns(
            target.cluster,
            target.family,
            service_name: target.family,
            desired_status: 'RUNNING'
          ).size

          if task_def.nil?
            warn "Skipping deploy target '#{target.name}' as it does not have a configured task_definition."
            next
          end

          revision = task_def[:revision]
          container_definitions = task_def[:container_definitions].select { |c| c[:name] == target.family }
          warn "Only displaying 1/#{container_definitions.size} containers" if container_definitions.size > 1
          container_definition = container_definitions.first

          row_data = target.to_h.merge(
            Image: container_definition[:image],
            CPU: container_definition[:cpu],
            Memory: container_definition[:memory],
            Revision: revision,
            Tasks: "#{service_tasks_running}/#{target.scale}"
          )

          table_header ||= row_data.keys.map(&:to_s)
          table_rows << row_data.values
        end

        table = TTY::Table.new(header: table_header, rows: table_rows)
        puts table.render(:ascii, padding: [0, 1])
      end

      def status(options)
        target = Broadside.config.get_target_by_name!(options[:target])
        cluster = target.cluster
        family = target.family
        pastel = Pastel.new
        debug "Getting status information about #{family}"

        output = [
          pastel.underline('Current task definition information:'),
          pastel.blue(PP.pp(EcsManager.get_latest_task_definition(family), ''))
        ]

        if options[:verbose]
          output << [
            pastel.underline('Current service information:'),
            pastel.bright_blue(PP.pp(EcsManager.ecs.describe_services(cluster: cluster, services: [family]), ''))
          ]
        end

        task_arns = Broadside::EcsManager.get_task_arns(cluster, family)
        if task_arns.empty?
          output << ["No running tasks found.\n"]
        else
          ips = EcsManager.get_running_instance_ips(cluster, family)

          if options[:verbose]
            output << [
              pastel.underline('Task information:'),
              pastel.bright_cyan(PP.pp(Broadside::EcsManager.ecs.describe_tasks(cluster: cluster, tasks: task_arns), ''))
            ]
          end

          output << [
            pastel.underline('Private IPs of instances running tasks:'),
            pastel.cyan(ips.map { |ip| "#{ip}: #{Broadside.config.ssh_cmd(ip)}" }.join("\n")) + "\n"
          ]
        end

        puts output.join("\n")
      end

      def run(options)
        EcsDeploy.new(options[:target], options).run_commands([options[:command]], started_by: 'run')
      end

      def logtail(options)
        lines = options[:lines] || 10
        deploy = EcsDeploy.new(options[:target])
        ip = deploy.get_running_instance_ip!(*options[:instance])
        info "Tailing logs for running container at #{ip}..."

        search_pattern = Shellwords.shellescape(deploy.family)
        cmd = "docker logs -f --tail=#{lines} `docker ps -n 1 --quiet --filter name=#{search_pattern}`"
        tail_cmd = Broadside.config.ssh_cmd(ip) + " '#{cmd}'"

        exec(tail_cmd)
      end

      def ssh(options)
        deploy = EcsDeploy.new(options[:target])
        ip = deploy.get_running_instance_ip!(*options[:instance])
        info "Establishing SSH connection to #{ip}..."

        exec(Broadside.config.ssh_cmd(ip))
      end

      def bash(options)
        deploy = EcsDeploy.new(options[:target])
        ip = deploy.get_running_instance_ip!(*options[:instance])
        info "Running bash for running container at #{ip}..."

        search_pattern = Shellwords.shellescape(deploy.family)
        cmd = "docker exec -i -t `docker ps -n 1 --quiet --filter name=#{search_pattern}` bash"
        exec(Broadside.config.ssh_cmd(ip, tty: true) + " '#{cmd}'")
      end
    end
  end
end
