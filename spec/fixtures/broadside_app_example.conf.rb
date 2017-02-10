Broadside.configure do |c|
  c.aws.credentials = Aws::Credentials.new('access', 'secret')
  c.ecs.default_cluster = cluster
  c.application = test_app
  c.default_docker_image = 'rails'
  c.logger.level = Logger::ERROR
  c.ssh = { user: user }
  c.targets = {
    test_target_name => test_target_config
  }
end
