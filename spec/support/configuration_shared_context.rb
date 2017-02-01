shared_context 'deploy configuration' do
  let(:test_app) { 'TEST_APP' }
  let(:cluster) { 'cluster' }
  let(:test_target) { :test_target }
  let(:dot_env_file) { File.join(FIXTURES_PATH, '.env.rspec') }
  let(:user) { 'test-user' }
  let(:test_target_config) { { scale: 1 } }

  before(:each) do
    Broadside.configure do |c|
      c.application = test_app
      c.docker_image = 'rails'
      c.logger.level = Logger::ERROR
      c.ecs.cluster = cluster
      c.ssh = { user: user }
      c.targets = { test_target => test_target_config }
    end
  end
end
