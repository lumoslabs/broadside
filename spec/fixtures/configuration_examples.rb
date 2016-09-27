shared_context 'base configuration' do
  before(:each) do
    Broadside.configure do |c|
      c.file = __FILE__
      c.base.application = 'TEST_APP'
      c.base.docker_image = 'rails'
      c.base.logger.level = Logger::ERROR
    end
  end
end

shared_context 'aws configuration' do
  include_context 'base configuration'
end

shared_context 'deploy configuration' do
  include_context 'base configuration'

  before(:each) do
    Broadside.configure do |c|
      c.deploy.tag = 'TEST_TAG'
      c.deploy.scale = 1
      c.deploy.rollback = 1
      c.deploy.instance = 1
      c.deploy.targets = {
        TEST_TARGET: {
          scale: 1,
          command: ['sleep', 'infinity'],
          env_file: File.join(FIXTURES_PATH, '.env.test')
        }
      }
      c.deploy.ssh = {
        user: 'test-user',
      }
    end
  end
end

shared_context 'ecs configuration' do
  include_context 'base configuration'

  before(:each) do
    Broadside.configure do |c|
      c.deploy.type = 'ecs'
      c.deploy.application = 'TEST_APP'
      c.deploy.docker_image = 'rails'
      c.ecs.cluster = 'cluster'
    end
  end
end

shared_context 'full configuration' do
  include_context 'aws configuration'
  include_context 'deploy configuration'
  include_context 'ecs configuration'
end
