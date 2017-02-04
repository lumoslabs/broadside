require 'pp'
require 'tty-table'

module Broadside
  module Command
    class << self
      def bootstrap(options)
        EcsDeploy.new(options[:target], options).bootstrap
      end

      def targets(options)
        table_header = nil
        table_rows = []

        Broadside.config.targets.each do |_, target|
          service_tasks_running = Broadside::EcsManager.get_task_arns(target.cluster, target.family, service_name: target.family, desired_status: 'RUNNING').size
          task_def = Broadside::EcsManager.get_latest_task_definition(target.family)

          if task_def.nil?
            warn "Skipping deploy target '#{target.name}' as it does not have a configured task_definition."
            next
          end

          revision = task_def[:revision]
          container_def = task_def[:container_definitions].select { |c| c[:name] == target.family }.first

          row_data = target.to_h.merge(
            Image: container_def[:image],
            CPU: container_def[:cpu],
            Memory: container_def[:memory],
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
        EcsDeploy.new(options[:target], options).run
      end

      def logtail(options)
        EcsDeploy.new(options[:target]).logtail(options)
      end

      def ssh(options)
        EcsDeploy.new(options[:target]).ssh
      end

      def bash(options)
        EcsDeploy.new(options[:target], options).bash
      end
    end
  end
end
