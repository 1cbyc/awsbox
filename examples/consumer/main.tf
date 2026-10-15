terraform {
  required_version = ">= 1.11.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.64"
    }
  }
}

module "workload" {
  source = "../.."

  name                            = "orders-api"
  environment                     = "staging"
  vpc_id                          = "vpc-0123456789abcdef0"
  private_subnet_ids              = ["subnet-0123456789abcdef0", "subnet-1123456789abcdef0"]
  load_balancer_security_group_id = "sg-0123456789abcdef0"
  https_egress_security_group_ids = ["sg-2123456789abcdef0"]
  target_group_arn                = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:targetgroup/orders/0123456789abcdef"
  image                           = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/orders-api@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  image_repository_arn            = "arn:aws:ecr:eu-west-1:123456789012:repository/orders-api"

  database_multi_az = false
  desired_count     = 2

  autoscaling = {
    max_capacity = 6
    cpu_target   = 70
  }

  tags = {
    Owner      = "platform"
    CostCenter = "engineering"
  }
}

resource "aws_iam_role_policy" "read_orders" {
  name = "read-orders"
  role = module.workload.task_role_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = ["arn:aws:s3:::orders-staging/*"]
    }]
  })
}
