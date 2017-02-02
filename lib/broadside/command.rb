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
        info "\n" + table.render(:ascii, padding: [0, 1])
      end

      def status(options)
        target = Broadside.config.target_from_name!(options[:target])

        info "Getting status information about #{target.family}"
        ips = EcsManager.get_running_instance_ips(target.cluster, target.family)
        output = [
          "\n---------------",
          "\nDeployed task definition information:\n",
          Pastel.new.blue(PP.pp(EcsManager.get_latest_task_definition(target.family), ''))
        ]

        if ips.empty?
          output << ["\nNo running tasks found.\n"]
        else
          output << [
            "\nPrivate ips of instances running tasks:\n",
            Pastel.new.blue(ips.join(' ')),
            "\n\nssh command:\n#{Pastel.new.cyan(Broadside.config.ssh_cmd(ips.first))}",
            "\n---------------\n"
          ]
        end

        info *output
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
