module Broadside
  module LoggingUtils
    %w(debug info warn error fatal).each do |log_level|
      define_method(log_level) do |*args|
        Broadside.config.logger.public_send(log_level.to_sym, args.join(' '))
      end
    end
  end
end
