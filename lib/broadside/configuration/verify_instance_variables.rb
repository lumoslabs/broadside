module Broadside
  module VerifyInstanceVariables
    def verify(*args)
      args.each do |var|
        if self.send(var).nil?
          raise Broadside::MissingVariableError, "Missing required #{self.class.to_s.split("::").last} variable '#{var}' !"
        end
      end
    end
  end
end
