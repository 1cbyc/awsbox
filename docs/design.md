# Design

## Boundary

The module begins where a network and TLS entry point already exist. The load balancer reaches tasks by security-group identity. Tasks reach PostgreSQL through another identity-based rule. Tasks receive no public address, and the database is never public.

The execution role contains only image-pull and log-delivery permissions. The application role starts empty and is an output so an environment can grant only its real API needs. The database master password is generated and rotated through the RDS and Secrets Manager integration rather than entering Terraform input or state as plaintext configuration.

## Availability and recovery

Two private subnets, two desired tasks, deployment rollback, Multi-AZ RDS, seven-day backups, final snapshots, and deletion protection are defaults. They are safeguards, not a recovery guarantee. A consumer must test restore timing and application consistency in its own account.

The ECS desired count ignores later Terraform drift so Application Auto Scaling can own it without a permanent plan conflict. This module does not create scaling alarms because useful thresholds require measured workload behavior.

## Cost and destructive behavior

RDS, Multi-AZ, Fargate tasks, CloudWatch logs, NAT gateways or endpoints, load balancing, data transfer, storage, Performance Insights, and image storage can all incur charges. The example disables Multi-AZ only to make that tradeoff visible for staging. Production should normally keep it enabled.

Disabling deletion protection and applying that change makes a later destroy possible. A destroy still requests a final snapshot and retains automated backups according to AWS behavior. ECR force deletion is disabled, so images must be deliberately removed before repository deletion.
