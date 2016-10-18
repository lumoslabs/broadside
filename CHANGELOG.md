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
