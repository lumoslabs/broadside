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

desc 'Enables debug mode'
switch [:D, :debug], negatable: false

desc 'Log level output'
arg_name 'LOGLEVEL'
flag [:l, :loglevel], must_match: %w(debug info warn error fatal)

def call_hook(type, command, options, args)
  hook = Broadside.config.public_send(type)
  return if hook.nil?
  raise "#{type} hook is not a callable proc" unless hook.is_a?(Proc)

  hook_args = {
    options: options,
    args: args,
  }

  if command.parent.is_a?(GLI::Command)
    hook_args.merge!({
      command: command.parent.name,
      subcommand: command.name
    })
  else
    hook_args.merge!(command: command.name)
  end

  debug "Calling #{type} with args '#{hook_args}'"
  hook.call(hook_args)
end

pre do |global, command, options, args|
  Broadside.load_config_file(global[:config])

  if global[:debug]
    Broadside.config.logger.level = ::Logger::DEBUG
    ENV['GLI_DEBUG'] = 'true'
  elsif global[:loglevel]
    Broadside.config.logger.level = ::Logger.const_get(global[:loglevel].upcase)
  end

  call_hook(:prehook, command, options, args)
  true
end

post do |global, command, options, args|
  call_hook(:posthook, command)
  true
end

on_error do |exception|
  case exception
  when Broadside::ConfigurationError
    error exception.message, "Run your last command with --help for more information."
    false # false skips default error handling
  else
    true
  end
end
