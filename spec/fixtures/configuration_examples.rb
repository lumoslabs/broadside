shared_context 'base configuration' do
  let(:test_app) { 'TEST_APP' }

  before(:each) do
    Broadside.configure do |c|
      c.config_file = __FILE__
      c.application = test_app
      c.docker_image = 'rails'
      c.logger.level = Logger::ERROR
    end
  end
end

shared_context 'deploy configuration' do
  include_context 'base configuration'

  let(:test_target) { :test_target }
  let(:env_file)    { '.env.rspec' }
  let(:test_target_config) do
    {
      scale: 1,
      command: ['sleep', 'infinity'],
      env_files: File.join(FIXTURES_PATH, env_file)
    }
  end

  before(:each) do
    Broadside.configure do |c|
      c.ecs.cluster = 'cluster'
      c.ssh = { user: 'test-user' }
      c.targets = { test_target => test_target_config }
    end
  end
end
