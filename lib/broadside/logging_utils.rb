module Broadside
  module LoggingUtils
    def debug(*args)
      Broadside.config.logger.debug(args.join(' '))
    end

    def info(*args)
      Broadside.config.logger.info(args.join(' '))
    end

    def warn(*args)
      Broadside.config.logger.warn(args.join(' '))
    end

    def error(*args)
      Broadside.config.logger.error(args.join(' '))
    end
  end
end