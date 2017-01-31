module Broadside
  module Utils
    def debug(*args)
      config.logger.debug(args.join(' '))
    end

    def info(*args)
      config.logger.info(args.join(' '))
    end

    def warn(*args)
      config.logger.warn(args.join(' '))
    end

    def error(*args)
      config.logger.error(args.join(' '))
    end

    def exception(*args)
      raise Broadside::Error, args.join("\n")
    end

    def config
      Broadside.config
    end
  end
end
