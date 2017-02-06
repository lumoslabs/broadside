# 3.0.0
### Breaking Changes
- `ssh`, `bash`, `logtail`, `status`, and `run` are now top level commands, not subcommands of `deploy`
- No more `RAKE_DB_MIGRATE` constant
- Configuration changes:
  - `config.git_repo=` and `config.type=` were removed.
  - `config.base` and `config.deploy` are no longer backwards compatible
  - `config.aws` region and credentials are now configured at `config.ecs.region` and `config.ecs.credentials`
  - `config.deploy.docker_image` is now `config.default_docker_image`
  - `config.deploy.cluster` is now `config.default_cluster`
  - `instance` can no longer be configured on a per `Target` basis

#### Added Features
- Allow configuration of separate `:docker_image` per target
- Put back ability to configure a default `:tag` per target
- Add `targets` command to display all the targets' deployed images and CPU/memory allocations
- `broadside status` has an added `--verbose` switch that displays service and task information
- [#11](https://github.com/lumoslabs/broadside/issues/11): Add option for ssh proxy user and proxy keyfile
- [#2](https://github.com/lumoslabs/broadside/issues/2): Add flag for changing loglevel, and add `--debug` switch that enables GLI debug output

#### General Improvements
- Only load `env_files` for the selected target (rather than preloading from unrelated targets)
- Make `env_files` configuration optional
- `Utils` has been replaced in favor of `LoggingUtils`
- Exceptions will be raised if a target is configured with an invalid hash key
- Tasks run have a more relevant `started_by` tag
- Default loglevel changed to INFO
- [#21](https://github.com/lumoslabs/broadside/issues/21) Print more useful messages when tasks die without exit codes.
- `Command` class to encapsulate the running of various commands
- Failed deploys will rollback to the last previously deployed scale

# 2.0.0
#### Breaking Changes
- [#27](https://github.com/lumoslabs/broadside/issues/27) `rake db:migrate` is no longer the default `predeploy_command`
- Remove ability to configure a default tag for each target

#### Added Features
- [#38](https://github.com/lumoslabs/broadside/issues/38) ECS cluster can be configured for each target by setting `config.ecs.cluster`

#### General Improvements
- `base` configuration has been removed - the main `Configuration` object holds all the `base` config. `Broadside.config.base` may be called but will display a deprecation warning.
- `deploy` configuration has been removed - primarily handled through the main `Configuration` object and in `targets=`. `Broadside.config.deploy` may be called but will display a deprecation warning.
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
