Broadside.configure do |c|
  c.aws.credentials = Aws::Credentials.new('access', 'secret')
  c.ecs.cluster = cluster
  c.application = test_app
  c.docker_image = 'rails'
  c.logger.level = Logger::ERROR
  c.targets = { test_target => test_target_config }
  c.ssh = {
    user: user
  }
end
