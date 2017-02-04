Broadside.configure do |c|
  c.ecs.credentials = Aws::Credentials.new('access', 'secret')
  c.ecs.cluster = cluster
  c.application = test_app
  c.docker_image = 'rails'
  c.logger.level = Logger::ERROR
  c.ssh = { user: user }
  c.targets = {
    test_target_name => test_target_config
  }
end
