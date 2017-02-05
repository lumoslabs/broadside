def add_tag_flag(cmd)
  cmd.desc 'Docker tag for application container'
  cmd.arg_name 'TAG'
  cmd.flag [:tag]
end

def add_target_flag(cmd)
  cmd.desc 'Deployment target to use, e.g. production_web'
  cmd.arg_name 'TARGET'
  cmd.flag [:t, :target], type: Symbol, required: true
end

def add_instance_flag(cmd)
  cmd.desc '0-based index into the array of running instances'
  cmd.default_value 0
  cmd.arg_name 'INSTANCE'
  cmd.flag [:n, :instance], type: Fixnum
end

def add_command_flags(cmd)
  add_instance_flag(cmd)
  add_target_flag(cmd)
end

desc 'Bootstrap your service and task definition from the configured definition.'
command :bootstrap do |bootstrap|
  add_tag_flag(bootstrap)
  add_target_flag(bootstrap)

  bootstrap.action do |_, options, _|
    Broadside::EcsDeploy.new(options[:target], options).bootstrap
  end
end

desc 'Gives an overview of all of the deploy targets'
command :targets do |targets|
  targets.action do |_, options, _|
    Broadside::Command.targets
  end
end

desc 'Gets information about what is currently deployed.'
command :status do |status|
  status.desc 'Additionally displays service and task information'
  status.switch :verbose, negatable: false

  add_target_flag(status)

  status.action do |_, options, _|
    Broadside::Command.status(options)
  end
end

desc 'Creates a single instance of the application to run a command.'
command :run do |run|
  run.desc 'Broadside::Command to run (wrap argument in quotes)'
  run.arg_name 'COMMAND'
  run.flag [:command], type: Array

  add_tag_flag(run)
  add_command_flags(run)

  run.action do |_, options, _|
    Broadside::Command.run(options)
  end
end

desc 'Tail the logs inside a running container.'
command :logtail do |logtail|
  logtail.desc 'Number of lines to tail'
  logtail.default_value 10
  logtail.arg_name 'TAIL_LINES'
  logtail.flag [:l, :lines], type: Fixnum

  add_command_flags(logtail)

  logtail.action do |_, options, _|
    Broadside::Command.logtail(options)
  end
end

desc 'Establish a secure shell on an instance running the container.'
command :ssh do |ssh|
  add_command_flags(ssh)

  ssh.action do |_, options, _|
    Broadside::Command.ssh(options)
  end
end

desc 'Establish a shell inside a running container.'
command :bash do |bash|
  add_command_flags(bash)

  bash.action do |_, options, _|
    Broadside::Command.bash(options)
  end
end

desc 'Deploy your application.'
command :deploy do |d|
  d.desc 'Deploys WITHOUT running predeploy commands'
  d.command :short do |short|
    add_tag_flag(short)
    add_target_flag(short)

    short.action do |_, options, _|
      Broadside::EcsDeploy.new(options[:target], options).short
    end
  end

  d.desc 'Deploys WITH running predeploy commands'
  d.command :full do |full|
    add_tag_flag(full)
    add_target_flag(full)

    full.action do |_, options, _|
      Broadside::EcsDeploy.new(options[:target], options).full
    end
  end

  d.desc 'Scales application to a given count'
  d.command :scale do |scale|
    scale.desc 'Specify a new scale for application'
    scale.arg_name 'NUM'
    scale.flag [:s, :scale], type: Fixnum

    add_target_flag(scale)

    scale.action do |_, options, _|
      Broadside::EcsDeploy.new(options[:target], options).scale(options)
    end
  end

  d.desc 'Rolls back n releases and deploys'
  d.command :rollback do |rollback|
    rollback.desc 'Number of releases to rollback'
    rollback.arg_name 'COUNT'
    rollback.flag [:r, :rollback], type: Fixnum

    add_target_flag(rollback)

    rollback.action do |_, options, _|
      Broadside::EcsDeploy.new(options[:target], options).rollback(*options[:rollback])
    end
  end
end
