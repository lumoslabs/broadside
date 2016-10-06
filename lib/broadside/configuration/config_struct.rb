module Broadside
  class Configuration
    class ConfigStruct
      def verify(*args)
        args.each do |var|
          if self.send(var).nil?
            raise Broadside::MissingVariableError, "Missing required #{self.class.to_s.split("::").last} variable '#{var}' !"
          end
        end
      end

      def to_h
        self.instance_variables.inject({}) do |h, var|
          h[var] = self.instance_variable_get(var)
          h
        end
      end

      def method_missing(m, *args, &block)
        warn "Unknown configuration '#{m}' provided, ignoring. Check your version of broadside?"
      end
    end
  end
end
