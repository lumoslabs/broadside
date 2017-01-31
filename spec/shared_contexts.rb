shared_context 'deploy configuration' do
  let(:test_app) { 'TEST_APP' }
  let(:cluster) { 'cluster' }
  let(:test_target) { :test_target }
  let(:dot_env_file) { File.join(FIXTURES_PATH, '.env.rspec') }
  let(:user) { 'test-user' }
  let(:test_target_config) do
    {
      scale: 1,
      command: ['sleep', 'infinity'],
      env_files: dot_env_file
    }
  end

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

shared_context 'ecs stubs' do
  let(:api_request_log) { [] }
  let(:ecs_stub) { build_stub_aws_client(Aws::ECS::Client, api_request_log) }
  let(:ec2_stub) { build_stub_aws_client(Aws::EC2::Client, api_request_log) }

  before(:each) do
    Broadside::EcsManager.instance_variable_set(:@ecs_client, ecs_stub)
    Broadside::EcsManager.instance_variable_set(:@ec2_client, ec2_stub)
  end
end
