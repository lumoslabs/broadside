Broadside.configure do |c|
  c.application = 'TEST_APP'
  c.docker_image = 'rails'
  c.logger.level = Logger::ERROR
  c.targets = {
    TEST_TARGET: {
      scale: 1,
      command: ['sleep', 'infinity'],
      env_files: File.join(FIXTURES_PATH, '.env.rspec')
    }
  }
  c.ssh = {
    user: 'app-default-user'
  }
end
