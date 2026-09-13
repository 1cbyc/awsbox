variable "name" {
  description = "Short workload name used in resource names and tags."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,27}[a-z0-9]$", var.name))
    error_message = "name must be 3 to 29 lowercase letters, digits, or hyphens and cannot end with a hyphen."
  }
}

variable "environment" {
  description = "Deployment environment recorded in resource tags."
  type        = string
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "environment must be development, staging, or production."
  }
}

variable "vpc_id" {
  description = "Existing VPC for the service and database security groups."
  type        = string
  validation {
    condition     = can(regex("^vpc-[0-9a-f]{8,17}$", var.vpc_id))
    error_message = "vpc_id must be an AWS VPC identifier."
  }
}

variable "private_subnet_ids" {
  description = "At least two existing private subnet IDs spanning availability zones."
  type        = set(string)
  validation {
    condition     = length(var.private_subnet_ids) >= 2 && alltrue([for id in var.private_subnet_ids : can(regex("^subnet-[0-9a-f]{8,17}$", id))])
    error_message = "private_subnet_ids must contain at least two valid subnet IDs."
  }
}

variable "load_balancer_security_group_id" {
  description = "Security group allowed to reach the application container port."
  type        = string
  validation {
    condition     = can(regex("^sg-[0-9a-f]{8,17}$", var.load_balancer_security_group_id))
    error_message = "load_balancer_security_group_id must be an AWS security group identifier."
  }
}

variable "https_egress_security_group_ids" {
  description = "Security groups for approved HTTPS destinations such as interface VPC endpoints."
  type        = set(string)
  default     = []
  validation {
    condition     = alltrue([for id in var.https_egress_security_group_ids : can(regex("^sg-[0-9a-f]{8,17}$", id))])
    error_message = "https_egress_security_group_ids must contain only AWS security group identifiers."
  }
}

variable "https_egress_prefix_list_ids" {
  description = "Managed prefix lists for approved HTTPS destinations such as an S3 gateway endpoint."
  type        = set(string)
  default     = []
  validation {
    condition     = alltrue([for id in var.https_egress_prefix_list_ids : can(regex("^pl-[0-9a-f]{8,17}$", id))])
    error_message = "https_egress_prefix_list_ids must contain only AWS managed prefix list identifiers."
  }
}

variable "target_group_arn" {
  description = "Existing ALB target group ARN using IP targets."
  type        = string
  validation {
    condition     = can(regex("^arn:[^:]+:elasticloadbalancing:[^:]+:[0-9]{12}:targetgroup/.+", var.target_group_arn))
    error_message = "target_group_arn must be an ELB target group ARN."
  }
}

variable "image" {
  description = "ECR container image reference pinned by sha256 digest."
  type        = string
  validation {
    condition     = can(regex("^[^[:space:]]+@sha256:[0-9a-f]{64}$", var.image))
    error_message = "image must be an immutable image reference ending in @sha256:<64 lowercase hex characters>."
  }
}

variable "image_repository_arn" {
  description = "ECR repository ARN containing image. This may be a bootstrap repository on the first deployment."
  type        = string
  validation {
    condition     = can(regex("^arn:[^:]+:ecr:[^:]+:[0-9]{12}:repository/.+", var.image_repository_arn))
    error_message = "image_repository_arn must be an ECR repository ARN."
  }
}

variable "container_port" {
  description = "TCP port exposed by the application container."
  type        = number
  default     = 8080
  validation {
    condition     = var.container_port >= 1024 && var.container_port <= 65535
    error_message = "container_port must be between 1024 and 65535."
  }
}

variable "health_check_path" {
  description = "Container-local HTTP liveness path."
  type        = string
  default     = "/health/live"
  validation {
    condition     = startswith(var.health_check_path, "/") && !strcontains(var.health_check_path, " ")
    error_message = "health_check_path must be an absolute path without spaces."
  }
}

variable "cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.cpu)
    error_message = "cpu must be a supported Fargate CPU value."
  }
}

variable "memory" {
  description = "Fargate task memory in MiB. This module validates the small workload combinations it supports."
  type        = number
  default     = 512
  validation {
    condition     = contains([512, 1024, 2048, 3072, 4096, 5120, 6144, 7168, 8192], var.memory)
    error_message = "memory must be one of the supported module values from 512 through 8192 MiB."
  }
}

variable "desired_count" {
  description = "Steady-state ECS task count."
  type        = number
  default     = 2
  validation {
    condition     = var.desired_count >= 2 && var.desired_count <= 20 && floor(var.desired_count) == var.desired_count
    error_message = "desired_count must be a whole number from 2 through 20."
  }
}

variable "database_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "app"
  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,62}$", var.database_name))
    error_message = "database_name must be a valid lowercase PostgreSQL identifier."
  }
}

variable "database_username" {
  description = "PostgreSQL administrator username. AWS manages its password in Secrets Manager."
  type        = string
  default     = "appadmin"
  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{2,30}$", var.database_username))
    error_message = "database_username must be 3 to 31 lowercase letters, digits, or underscores."
  }
}

variable "database_instance_class" {
  description = "RDS instance class. Burstable Graviton classes are the intended default path."
  type        = string
  default     = "db.t4g.micro"
  validation {
    condition     = can(regex("^db\\.(t4g|m7g|r7g)\\.[a-z0-9]+$", var.database_instance_class))
    error_message = "database_instance_class must use an allowed t4g, m7g, or r7g class."
  }
}

variable "database_allocated_storage" {
  description = "Initial gp3 database storage in GiB."
  type        = number
  default     = 20
  validation {
    condition     = var.database_allocated_storage >= 20 && var.database_allocated_storage <= 1024
    error_message = "database_allocated_storage must be from 20 through 1024 GiB."
  }
}

variable "database_max_allocated_storage" {
  description = "RDS storage autoscaling ceiling in GiB."
  type        = number
  default     = 100
}

variable "database_multi_az" {
  description = "Whether RDS maintains a synchronous standby in another availability zone."
  type        = bool
  default     = true
}

variable "database_deletion_protection" {
  description = "Protect the RDS instance from deletion. Disable only during a reviewed teardown."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch application log retention."
  type        = number
  default     = 30
  validation {
    condition     = contains([14, 30, 60, 90, 120, 150, 180, 365], var.log_retention_days)
    error_message = "log_retention_days must be an allowed CloudWatch retention value of at least 14 days."
  }
}

variable "tags" {
  description = "Additional tags. Name, Environment, and ManagedBy cannot be overridden."
  type        = map(string)
  default     = {}
  validation {
    condition     = length(setintersection(toset(keys(var.tags)), toset(["Name", "Environment", "ManagedBy"]))) == 0
    error_message = "tags cannot override Name, Environment, or ManagedBy."
  }
}
