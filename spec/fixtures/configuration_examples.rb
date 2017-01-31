shared_context 'deploy configuration' do
  let(:test_app) { 'TEST_APP' }
  let(:cluster) { 'cluster' }
  let(:test_target) { :test_target }
  let(:env_file)    { '.env.rspec' }
  let(:user) { 'test-user' }
  let(:test_target_config) do
    {
      scale: 1,
      command: ['sleep', 'infinity'],
      env_files: File.join(FIXTURES_PATH, env_file)
    }
  end

  before(:each) do
    Broadside.configure do |c|
      c.application = test_app
      c.docker_image = 'rails'
      c.logger.level = Logger::ERROR
      c.ecs.cluster = cluster
      c.ssh = { user: 'test-user' }
      c.targets = { test_target => test_target_config }
    end
  end
end
