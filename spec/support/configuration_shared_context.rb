shared_context 'deploy configuration' do
  let(:test_app) { 'TEST_APP' }
  let(:cluster) { 'cluster' }
  let(:test_target_name) { :test_target }
  let(:dot_env_file) { File.join(FIXTURES_PATH, '.env.rspec') }
  let(:user) { 'test-user' }
  let(:test_target_config) { { scale: 1 }.merge(local_target_config) }
  let(:local_target_config) { {} }

  before(:each) do
    binding.eval File.read(File.join(FIXTURES_PATH, 'broadside_app_example.conf.rb'))
  end
end
