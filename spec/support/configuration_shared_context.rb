shared_context 'deploy configuration' do
  let(:test_app) { 'TEST_APP' }
  let(:cluster) { 'cluster' }
  let(:test_target_name) { :test_target }
  let(:user) { 'test-user' }
  let(:test_target_config) { { scale: 1 }.merge(local_target_config) }
  let(:local_target_config) { {} }
  let(:arn) { 'arn:aws:ecs:us-east-1:1234' }
  let(:system_config_path) { File.join(FIXTURES_PATH, 'broadside_system_example.conf.rb') }
  let(:app_config_path) { File.join(FIXTURES_PATH, 'broadside_app_example.conf.rb') }

  before(:each) do
    stub_const('Broadside::USER_CONFIG_FILE', system_config_path)
    binding.eval(File.read(app_config_path))
  end
end
