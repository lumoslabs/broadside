Broadside.configure do |c|
  c.base.application = 'TEST_APP'
  c.base.docker_image = 'rails'
  c.base.logger.level = Logger::ERROR
  c.deploy.tag = 'TEST_TAG'
  c.deploy.targets = {
    TEST_TARGET: {
      scale: 1,
      command: ['sleep', 'infinity'],
      env_file: './.env.test'
    }
  }
end
