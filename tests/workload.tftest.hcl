mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "eu-west-1" }
  }
}

override_resource {
  target          = aws_security_group.service
  override_during = plan
  values          = { id = "sg-1123456789abcdef0" }
}

variables {
  name                            = "orders-api"
  environment                     = "production"
  vpc_id                          = "vpc-0123456789abcdef0"
  private_subnet_ids              = ["subnet-0123456789abcdef0", "subnet-1123456789abcdef0"]
  load_balancer_security_group_id = "sg-0123456789abcdef0"
  https_egress_security_group_ids = ["sg-2123456789abcdef0"]
  target_group_arn                = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:targetgroup/orders/0123456789abcdef"
  image                           = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/orders-api@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  image_repository_arn            = "arn:aws:ecr:eu-west-1:123456789012:repository/orders-api"
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = aws_ecr_repository.app.image_tag_mutability == "IMMUTABLE" && aws_ecr_repository.app.force_delete == false
    error_message = "The registry must keep immutable tags and resist forced deletion."
  }
  assert {
    condition     = aws_db_instance.app.storage_encrypted && aws_db_instance.app.deletion_protection && !aws_db_instance.app.publicly_accessible
    error_message = "The database must be encrypted, private, and deletion protected."
  }
  assert {
    condition     = aws_db_instance.app.backup_retention_period >= 7 && !aws_db_instance.app.skip_final_snapshot
    error_message = "The database must retain backups and require a final snapshot."
  }
  assert {
    condition     = aws_ecs_service.app.network_configuration[0].assign_public_ip == false && aws_ecs_service.app.deployment_circuit_breaker[0].rollback
    error_message = "Tasks must remain private and failed deployments must roll back."
  }
  assert {
    condition     = local.container_health_command[0] == "CMD" && local.container_health_command[1] == "wget"
    error_message = "The health check must avoid shell evaluation."
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.database.referenced_security_group_id == aws_security_group.service.id
    error_message = "Database ingress must be sourced from the service security group."
  }
}

run "autoscaling_contract" {
  command = plan
  variables {
    autoscaling = {
      max_capacity       = 8
      cpu_target         = 70
      scale_in_cooldown  = 600
      scale_out_cooldown = 30
    }
  }

  assert {
    condition     = aws_appautoscaling_target.service[0].min_capacity == 2 && aws_appautoscaling_target.service[0].max_capacity == 8
    error_message = "Autoscaling must preserve the steady-state minimum and enforce the configured maximum."
  }
  assert {
    condition     = aws_appautoscaling_policy.cpu[0].target_tracking_scaling_policy_configuration[0].target_value == 70
    error_message = "Autoscaling must use the configured CPU target."
  }
}

run "reject_mutable_image" {
  command = plan
  variables { image = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/orders-api:latest" }
  expect_failures = [var.image]
}

run "reject_single_subnet" {
  command = plan
  variables { private_subnet_ids = ["subnet-0123456789abcdef0"] }
  expect_failures = [var.private_subnet_ids]
}

run "reject_storage_ceiling_below_initial" {
  command = plan
  variables {
    database_allocated_storage     = 100
    database_max_allocated_storage = 50
  }
  expect_failures = [aws_db_instance.app]
}

run "reject_invalid_task_size" {
  command = plan
  variables {
    cpu    = 256
    memory = 8192
  }
  expect_failures = [aws_ecs_task_definition.app]
}

run "reject_missing_https_egress" {
  command = plan
  variables {
    https_egress_security_group_ids = []
  }
  expect_failures = [aws_ecs_service.app]
}

run "reject_health_command_injection" {
  command = plan
  variables { health_check_path = "/health;id" }
  expect_failures = [var.health_check_path]
}

run "reject_autoscaling_below_steady_state" {
  command = plan
  variables {
    autoscaling = {
      max_capacity = 1
      cpu_target   = 70
    }
  }
  expect_failures = [var.autoscaling]
}
