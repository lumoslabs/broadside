Broadside.configure do |c|
  c.base.application = 'system-default-application'
  c.deploy.ssh = {
    user: 'system-default-user',
  }
end
