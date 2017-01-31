# 3.0.0
- **BREAKING CHANGE**: `ssh`, `bash`, `logtail`, `status`, and `run` are now top level commands, not subcommands of `deploy`
- **BREAKING CHANGE**: `config.git_repo=` and `config.type=` were removed.
- **BREAKING CHANGE**: `config.base` and `config.deploy` are no longer backwards compatible
- **BREAKING CHANGE**: `instance` can no longer be configured on a per `Target` basis
- *NEW FEATURE*: Allow per target `:docker_image` configuration
- *NEW FEATURE*: Put back per target `:tag` configuration
- *NEW FEATURE*: Add `list_targets` command to display all the targets' deployed images and CPU/memory allocations
- Only load `env_files` for the selected target (AKA don't preload everything when you aren't using it)
- Make `env_files` configuration optional
- No more `Utils` module, just `LoggingUtils`

# 2.0.0
- **BREAKING CHANGE**: `rake db:migrate` is no longer the default `predeploy_command`
- **BREAKING CHANGE**: Remove per target `tag:` config - `--tag` must be passed on the command line
- *NEW FEATURE*: `:cluster` can be configured on a per target basis to overload `config.ecs.cluster`
- There is no more `base` configuration - the main `Configuration` object holds all the `base` config.  You can still call `Broadside.config.base` though you will get a deprecation warning.
- There is no more `deploy` configuration - most of that is handled in the main `Configuration` object and in `targets=`. You can still call `Broadside.config.deploy` though you will get a deprecation warning.
- `Target` is a first class object
- `Deploy` is composed of a `Target` plus command line options

# 1.4.0
- [#42](https://github.com/lumoslabs/broadside/pull/42/files): Update the task definition when running bootstrap

# 1.3.0
- [#41](https://github.com/lumoslabs/broadside/pull/41/files): Introduce the concept of bootstrap commands, which are designed to be run when setting up a new server or environment.

# 1.2.1
- [#35](https://github.com/lumoslabs/broadside/pull/35/files): Allows logtail to display more than 10 lines

# 1.2.0
- [#32](https://github.com/lumoslabs/broadside/pull/32): Deploys will also update service configs defined in a deploy target (see full list in the [AWS Docs](https://docs.aws.amazon.com/sdkforruby/api/Aws/ECS/Client.html#create_service-instance_method))
- Updates additional container definition configs like cpu, memory. See full list in the [AWS Docs](https://docs.aws.amazon.com/sdkforruby/api/Aws/ECS/Client.html#register_task_definition-instance_method)
- [#24](https://github.com/lumoslabs/broadside/pull/24): Refactored most ECS-specific utility methods into a separate class

# 1.1.1
- [#25](https://github.com/lumoslabs/broadside/issues/25): Fix issue with undefined local variable 'ecs'

# 1.1.0
- [#16](https://github.com/lumoslabs/broadside/pull/16): Add bootstrap command; add specs

# 1.0.3
- [#12](https://github.com/lumoslabs/broadside/issues/12): Fix isssue with not being to use ssh, bash, logtail commands without specifying instance index

# 1.0.2
- [#7](https://github.com/lumoslabs/broadside/issues/7): Fix issue with getting the wrong container's exit code when running tasks
- Bump aws-sdk version from `2.2.7` to `2.3`

# 1.0.1
- [#3](https://github.com/lumoslabs/broadside/issues/3): Fix task definition pagination

# 1.0.0
- Initial release.
