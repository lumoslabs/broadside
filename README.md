# Broadside
A command-line tool for deploying applications on AWS EC2 Container Service (ECS)

This tool is primarily intended for use with ruby applications.


## Overview
Amazon ECS presents a low barrier to entry for production-level docker applications. Combined with ECS's built-in blue-green deployment, Elastic Load Balancers, Autoscale Groups, and CloudWatch, one can set up a robust cluster that can scale to serve any number of applications in a short amount of time. Broadside seeks to leverage these benefits and improve the deployment process for developers.

Broadside offers a simple command-line interface to perform deployments on ECS. It does not attempt to handle operational tasks like infrastructure setup and configuration, which are better suited for tools like [terraform](https://www.terraform.io/). This allows applications using broadside to employ a clean configuration file that looks something like:

```ruby
Broadside.configure do |config|
  config.base.application = 'hello_world'
  config.base.docker_image = 'lumoslabs/hello_world'
  config.deploy.type = 'ecs'
  config.ecs.cluster = 'micro-cluster'
  config.deploy.targets = {
    production_web: {
      scale: 7,
      command: ['bundle', 'exec', 'unicorn', '-c', 'config/unicorn.conf.rb'],
      env_file: '../.env.production'
      predeploy_commands: [
        ['bundle', 'exec', 'rake', 'db:migrate'],
        ['bundle', 'exec', 'rake', 'data:migrate']
      ]
    },
    production_worker: {
      scale: 15,
      command: ['bundle', 'exec', 'rake', 'resque:work'],
      env_file: '../.env.production'
    }
    staging_web: {
      scale: 1,
      command: ['bundle', 'exec', 'puma'],
      env_file: '../.env.staging'
    }
    staging_worker: {
      scale: 1,
      command: ['bundle', 'exec', 'rake', 'resque:work'],
      env_file: '../.env.staging'
    }
  }
end
```

From here, developers can use broadside's command-line interface to initiate a basic deployment:
```
broadside deploy short --target production_web --tag $GIT_SHA
```
or run
```
broadside deploy full --target production_web --tag $GIT_SHA
```
which will run the listed `predeploy_commands` listed in the config above prior to the deployment.

In the case of an error or timeout during a deploy, broadside will automatically rollback to the latest stable version. You can perform manual rollbacks as well through the command-line.

See the complete command-line reference in the wiki.


## Setup
First, install broadside by adding it to your application gemfile:
```
gem 'broadside'
```

Then run
```
bundle install
bundle binstubs broadside
```

It's recommended that you specify broadside as a development gem so it doesn't inflate your production image.

You can now run the executable in your app directory:
```
bin/broadside --help
```

For a full application setup, see the detailed instructions in the wiki.


## Contributing
Pull requests, bug reports, and feature suggestions are welcome! Before starting on a contribution, I recommend opening an issue or replying to an existing one to give others some initial context on the work needing to be done.

1. Create your feature branch (`git checkout -b my-new-feature`)
2. Commit your changes (`git commit -am 'Add some feature'`)
3. Push to the branch (`git push origin my-new-feature`)
4. Create a new Pull Request
