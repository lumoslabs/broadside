# GLI type coercions
accept Symbol do |val|
  val.to_sym
end
accept Array do |val|
  val.split(' ')
end
accept Fixnum do |val|
  val.to_i
end

desc 'Configuration file to use.'
default_value 'config/broadside.conf.rb'
arg_name 'FILE'
flag [:c, :config]

def call_hook(type, command)
  hook = Broadside.config.public_send(type)

  if hook.is_a?(Proc)
    hook_args =
      if command.parent.is_a?(GLI::Command)
        {
          command: command.parent.name,
          subcommand: command.name
        }
      else
        { command: command.name }
      end
    debug "Calling", type, "with args", hook_args
    hook.call(hook_args)
  end
end

pre do |global, command, options, args|
  Broadside.load_config(global[:config])
  call_hook(:prehook, command)
  true
end

post do |global, command, options, args|
  call_hook(:posthook, command)
  true
end

on_error do |exception|
  # false skips default error handling
  case exception
  when Broadside::MissingVariableError
    error exception.message, "Run your last command with --help for more information."
    false
  else
    true
  end
end
