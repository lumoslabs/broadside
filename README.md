# Broadside [![Build Status](https://travis-ci.org/lumoslabs/broadside.svg?branch=master)](https://travis-ci.org/lumoslabs/broadside)

A command-line tool for deploying applications on AWS EC2 Container Service (ECS)

## Overview
Amazon ECS presents a low barrier to entry for production-level docker applications. Combined with ECS's built-in blue-green deployment, Elastic Load Balancers, Autoscale Groups, and CloudWatch, one can set up a robust cluster that can scale to serve any number of applications in a short amount of time. Broadside seeks to leverage these benefits and improve the deployment process for developers.

Broadside offers a simple command-line interface to perform deployments on ECS. It does not attempt to handle operational tasks like infrastructure setup and configuration, which are better suited for tools like [terraform](https://www.terraform.io/).

Applications using broadside employ a configuration file that looks something like:

```ruby
Broadside.configure do |config|
  config.application = 'hello_world'
  config.docker_image = 'lumoslabs/hello_world'
  config.ecs.cluster = 'production-cluster'
  config.targets = {
    production_web: {
      scale: 7,
      command: ['bundle', 'exec', 'unicorn', '-c', 'config/unicorn.conf.rb'],
      env_file: '.env.production'
      predeploy_commands: [
        ['bundle', 'exec', 'rake', 'db:migrate']
        ['bundle', 'exec', 'rake', 'data:migrate']
      ]
    },
    staging_web: {
      cluster: 'staging-cluster', # Overrides config.ecs.cluster for this target only
      scale: 1,
      command: ['bundle', 'exec', 'puma'],
      env_file: '../.env.staging',
      tag: 'latest_staging' # Either configure the tag per target or pass --tag to the deploy command
    },
    # Example with a task_definition and service configuration which you use to bootstrap a service and
    # initial task definition.  Accepts all the options AWS does - read their documentation for details:
    #
    # Service config: https://docs.aws.amazon.com/sdkforruby/api/Aws/ECS/Client.html#create_service-instance_method
    # Task Definition Config: https://docs.aws.amazon.com/sdkforruby/api/Aws/ECS/Client.html#register_task_definition-instance_method
    json_blob_stream: {
      scale: 1,
      command: ['java', '-cp', '*:.', 'path.to.MyClass'],
      service_config: {
        deployment_configuration: {
          minimum_healthy_percent: 0.5,
        }
      },
      task_definition_config: {
        container_definitions: [
          {
            cpu: 1,
            memory: 2000,
          }
        ]
      }
    }
  }
end
```

From here, developers can use broadside's command-line interface to initiate a basic deployment:

```bash
broadside deploy short --target production_web --tag $GIT_TAG
```

If you run:

```bash
broadside deploy full --target production_web --tag $GIT_TAG
```

the `deploy full` will run the configured `predeploy_commands` prior to the actual deployment.

In the case of an error or timeout during a deploy, broadside will automatically rollback to the latest stable version. You can perform manual rollbacks as well through the command-line.

[See the complete command-line reference in the wiki](https://github.com/lumoslabs/broadside/wiki/CLI-reference).


## Installation
### Via Gemfile
First, install broadside by adding it to your application `Gemfile`:

```ruby
gem 'broadside'
```

Then run
```bash
bundle install
```

You can now run the executable in your app directory:
```bash
bundle exec broadside --help
```

`bundler` can also install binstubs for you - small scripts in the `/bin` directory of your application that will mean you can type `bin/broadside do_something` instead of `bundle exec broadside do_something`.  If you want to save the typing, run:

```bash
bundle binstubs broadside
```

### System Wide
If you are unfamiliar with `bundler` and/or just want to install it for the whole system like a real cowboy, you can just do
```
gem install broadside
```

## Configuration
For full application setup including tips about setting up your Amazon Web Services, see the [detailed instructions in the wiki](https://github.com/lumoslabs/broadside/wiki).

## Debugging
Broadside is pretty terse with its error output; you can get a full stacktrace with `export GLI_DEBUG=true`

## Contributing
Pull requests, bug reports, and feature suggestions are welcome! Before starting on a contribution, we recommend opening an issue or replying to an existing one to give others some initial context on the work needing to be done.
