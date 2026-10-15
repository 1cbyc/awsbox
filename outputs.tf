output "repository_url" {
  description = "ECR repository URL for immutable image publication."
  value       = aws_ecr_repository.app.repository_url
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.app.name
}

output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.app.name
}

output "autoscaling_configuration" {
  description = "Effective target-tracking settings, or null when service autoscaling is disabled."
  value = var.autoscaling == null ? null : {
    min_capacity       = var.desired_count
    max_capacity       = var.autoscaling.max_capacity
    cpu_target         = var.autoscaling.cpu_target
    scale_in_cooldown  = var.autoscaling.scale_in_cooldown
    scale_out_cooldown = var.autoscaling.scale_out_cooldown
  }
}

output "task_role_arn" {
  description = "Application task role ARN to extend with narrow workload permissions."
  value       = aws_iam_role.task.arn
}

output "task_role_name" {
  description = "Application task role name for narrowly scoped consumer-managed inline policies."
  value       = aws_iam_role.task.name
}

output "database_endpoint" {
  description = "Private PostgreSQL endpoint."
  value       = aws_db_instance.app.endpoint
}

output "database_master_secret_arn" {
  description = "AWS-managed master credential secret ARN. Grant read access only to a migration path or explicit application policy."
  value       = try(aws_db_instance.app.master_user_secret[0].secret_arn, null)
  sensitive   = true
}

output "service_security_group_id" {
  description = "Security group attached to ECS tasks."
  value       = aws_security_group.service.id
}
