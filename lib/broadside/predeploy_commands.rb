# Here rest some commonly used predeploy commands, so they can be included by constant name instead of
# having to retype them in every config file.
module Broadside
  module PredeployCommands
    RAKE_DB_MIGRATE = ['bundle', 'exec', 'rake', '--trace', 'db:migrate']
  end
end
