mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "eu-west-1" }
  }
}

override_resource {
  target          = module.workload.aws_security_group.service
  override_during = plan
  values          = { id = "sg-1123456789abcdef0" }
}

run "consumer_adopts_scaling_and_task_policy" {
  command = plan

  assert {
    condition     = module.workload.autoscaling_configuration.min_capacity == 2 && module.workload.autoscaling_configuration.max_capacity == 6
    error_message = "The consumer must keep two tasks and permit scaling to six."
  }

  assert {
    condition     = aws_iam_role_policy.read_orders.role == module.workload.task_role_name
    error_message = "The consumer policy must extend the workload-specific task role."
  }
}
