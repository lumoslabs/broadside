# Broadside [![Build Status](https://travis-ci.org/lumoslabs/broadside.svg?branch=master)](https://travis-ci.org/lumoslabs/broadside)

A [GLI](https://github.com/davetron5000/gli) based command-line tool for deploying applications on [AWS EC2 Container Service (ECS)](https://aws.amazon.com/ecs/)

## Overview
Amazon ECS presents a low barrier to entry for production-level docker applications. Combined with ECS's built-in blue-green deployment, Elastic Load Balancers, Autoscale Groups, and CloudWatch, one can theoretically set up a robust cluster that can scale to serve any number of applications in a short amount of time. The ECS GUI, CLI, overall architecture are not the easiest to work with, however, so Broadside seeks to leverage the [ECS ruby API](http://docs.aws.amazon.com/sdkforruby/api/Aws/ECS.html) to dramatically simplify and improve the configuration and deployment process for developers, offering a simple command line interface and configuration format that should meet most needs.

Broadside does _not_ attempt to handle operational tasks like infrastructure setup and configuration, which are better suited to tools like [terraform](https://www.terraform.io/).

### Capabilities

- **Trigger** ECS deployments
- **Launch** a bash shell directly onto a running container in the cluster
- **SSH** directly onto a host running a container
- **Launch** an ECS task running an arbitrary command
- **Tail** logs of a running container
- **Scale** an existing deployment on the fly

### Example Config for Quickstarters
Applications using broadside employ a configuration file that looks something like:

```ruby
Broadside.configure do |config|
  config.application = 'hello_world'
  config.default_docker_image = 'lumoslabs/hello_world'
  config.aws.ecs_default_cluster = 'production-cluster'
  config.aws.region = 'us-east-1'                  # 'us-east-1 is the default
  config.targets = {
    production_web: {
      scale: 7,
      command: ['bundle', 'exec', 'unicorn', '-c', 'config/unicorn.conf.rb'],
      env_file: '.env.production'
      predeploy_commands: [
        ['bundle', 'exec', 'rake', 'db:migrate'],
        ['bundle', 'exec', 'rake', 'data:migrate']
      ]
    },
    # If you have multiple images or clusters, you can configure them per target
    staging_web: {
      scale: 1,
      command: ['bundle', 'exec', 'puma'],
      env_file: '.env.staging',
      tag: 'latest',                                # Set a default tag for this target
      cluster: 'staging-cluster',                   # Overrides config.ecs.cluster
      docker_image: 'lumoslabs/staging_hello_world' # Overrides config.docker_image
    },
    json_stream: {
      scale: 1,
      command: ['java', '-cp', '*:.', 'path.to.MyClass'],
      # This target has a task_definition and service config which you use to bootstrap a new AWS Service
      service_config: { deployment_configuration: { minimum_healthy_percent: 0.5 } },
      task_definition_config: { container_definitions: [ { cpu: 1, memory: 2000, } ] }
    }
  }
end
```

From here, developers can use broadside's command-line interface to initiate a basic deployment and launch the
configured `command` as an ECS Service:

```bash
bundle exec broadside deploy full --target production_web --tag v.1.1.example.tag
```

In the case of an error or timeout during a deploy, broadside will automatically rollback to the latest stable version. You can perform manual rollbacks as well through the command-line.

[For more information on broadside commands, see the complete command-line reference in the wiki](https://github.com/lumoslabs/broadside/wiki/CLI-reference).


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

You may also generate binstubs using
```bash
bundle binstubs broadside
```

### System Wide
Alternatively, you can install broadside using:
```
gem install broadside
```

## Configuration
For full application setup, see the [detailed instructions in the wiki](https://github.com/lumoslabs/broadside/wiki).

## Debugging
Use the `--debug` switch to enable stacktraces and debug output.

## Contributing
Pull requests, bug reports, and feature suggestions are welcome! Before starting on a contribution, we recommend opening an issue or replying to an existing one to give others some initial context on the work needing to be done.
