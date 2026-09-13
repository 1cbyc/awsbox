locals {
  tags = merge(var.tags, {
    Name        = var.name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_ecr_repository" "app" {
  name                 = var.name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images after seven days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 7
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/ecs/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

locals {
  ecs_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-execution"
  assume_role_policy = local.ecs_assume_role_policy
  tags               = local.tags
}

resource "aws_iam_role_policy" "execution" {
  name = "pull-image-and-write-logs"
  role = aws_iam_role.execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"]
        Resource = [aws_ecr_repository.app.arn, var.image_repository_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.app.arn}:*"
      }
    ]
  })
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = local.ecs_assume_role_policy
  tags               = local.tags
}

resource "aws_security_group" "service" {
  name_prefix = "${var.name}-service-"
  description = "Restrict application ingress to the load balancer"
  vpc_id      = var.vpc_id
  tags        = local.tags

  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "service" {
  security_group_id            = aws_security_group.service.id
  referenced_security_group_id = var.load_balancer_security_group_id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  description                  = "Application traffic from the load balancer"
}

resource "aws_vpc_security_group_egress_rule" "service_https_security_group" {
  for_each                     = var.https_egress_security_group_ids
  security_group_id            = aws_security_group.service.id
  referenced_security_group_id = each.value
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "TLS to an approved endpoint security group"
}

resource "aws_vpc_security_group_egress_rule" "service_https_prefix_list" {
  for_each          = var.https_egress_prefix_list_ids
  security_group_id = aws_security_group.service.id
  prefix_list_id    = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "TLS to an approved managed prefix list"
}

resource "aws_security_group" "database" {
  name_prefix = "${var.name}-database-"
  description = "Accept PostgreSQL only from application tasks"
  vpc_id      = var.vpc_id
  tags        = local.tags

  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "database" {
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = aws_security_group.service.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "PostgreSQL from application tasks"
}

resource "aws_vpc_security_group_egress_rule" "service_database" {
  security_group_id            = aws_security_group.service.id
  referenced_security_group_id = aws_security_group.database.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "PostgreSQL to the workload database"
}

resource "aws_db_subnet_group" "app" {
  name       = var.name
  subnet_ids = sort(tolist(var.private_subnet_ids))
  tags       = local.tags
}

resource "aws_db_instance" "app" {
  identifier                      = var.name
  engine                          = "postgres"
  engine_version                  = "17"
  instance_class                  = var.database_instance_class
  db_name                         = var.database_name
  username                        = var.database_username
  manage_master_user_password     = true
  allocated_storage               = var.database_allocated_storage
  max_allocated_storage           = var.database_max_allocated_storage
  storage_type                    = "gp3"
  storage_encrypted               = true
  multi_az                        = var.database_multi_az
  publicly_accessible             = false
  db_subnet_group_name            = aws_db_subnet_group.app.name
  vpc_security_group_ids          = [aws_security_group.database.id]
  backup_retention_period         = 7
  backup_window                   = "03:00-04:00"
  maintenance_window              = "sun:04:00-sun:05:00"
  auto_minor_version_upgrade      = true
  deletion_protection             = var.database_deletion_protection
  skip_final_snapshot             = false
  final_snapshot_identifier       = "${var.name}-final"
  copy_tags_to_snapshot           = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = true
  apply_immediately               = false
  tags                            = local.tags

  lifecycle {
    precondition {
      condition     = var.database_max_allocated_storage >= var.database_allocated_storage
      error_message = "database_max_allocated_storage must be at least database_allocated_storage."
    }
  }
}

resource "aws_ecs_cluster" "app" {
  name = var.name
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = local.tags
}

resource "aws_ecs_task_definition" "app" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
  container_definitions = jsonencode([{
    name                   = "app"
    image                  = var.image
    essential              = true
    readonlyRootFilesystem = true
    user                   = "10001:10001"
    portMappings = [{
      name          = "http"
      containerPort = var.container_port
      hostPort      = var.container_port
      protocol      = "tcp"
      appProtocol   = "http"
    }]
    environment = [
      { name = "APP_ENV", value = var.environment },
      { name = "DB_HOST", value = aws_db_instance.app.address },
      { name = "DB_PORT", value = tostring(aws_db_instance.app.port) },
      { name = "DB_NAME", value = var.database_name },
      { name = "DB_USER", value = var.database_username }
    ]
    mountPoints = []
    volumesFrom = []
    linuxParameters = {
      capabilities       = { drop = ["ALL"] }
      initProcessEnabled = true
    }
    healthCheck = {
      command     = ["CMD-SHELL", "wget -q -O /dev/null http://127.0.0.1:${var.container_port}${var.health_check_path} || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 20
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name
        awslogs-region        = data.aws_region.current.region
        awslogs-stream-prefix = "app"
      }
    }
  }])
  tags = local.tags

  lifecycle {
    precondition {
      condition = (
        (var.cpu == 256 && contains([512, 1024, 2048], var.memory)) ||
        (var.cpu == 512 && contains([1024, 2048, 3072, 4096], var.memory)) ||
        (var.cpu == 1024 && var.memory >= 2048 && var.memory <= 8192) ||
        (var.cpu == 2048 && var.memory >= 4096 && var.memory <= 8192) ||
        (var.cpu == 4096 && var.memory >= 8192)
      )
      error_message = "cpu and memory must form a supported Fargate combination."
    }
  }
}

data "aws_region" "current" {}

resource "aws_ecs_service" "app" {
  name                               = var.name
  cluster                            = aws_ecs_cluster.app.id
  task_definition                    = aws_ecs_task_definition.app.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  health_check_grace_period_seconds  = 60
  enable_execute_command             = false
  wait_for_steady_state              = false
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  propagate_tags                     = "SERVICE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = sort(tolist(var.private_subnet_ids))
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "app"
    container_port   = var.container_port
  }

  lifecycle {
    ignore_changes = [desired_count]
    precondition {
      condition     = length(var.https_egress_security_group_ids) + length(var.https_egress_prefix_list_ids) > 0
      error_message = "At least one approved HTTPS egress security group or prefix list is required for image pulls and log delivery."
    }
  }

  depends_on = [aws_iam_role_policy.execution]
  tags       = local.tags
}
