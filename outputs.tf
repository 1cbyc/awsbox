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

output "task_role_arn" {
  description = "Application task role ARN to extend with narrow workload permissions."
  value       = aws_iam_role.task.arn
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
