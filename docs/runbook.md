# Runbook

## Pre-deployment

Confirm the image digest exists for Linux ARM64 and passes the organization's vulnerability threshold. Validate that the container runs as UID and GID 10001 with a read-only root filesystem, no Linux capabilities, and the documented health endpoint. Review a saved Terraform plan and have another engineer approve deletes, replacements, IAM changes, public routing, and protection changes.

Confirm subnet availability-zone spread and the VPC endpoints for ECR API, ECR Docker, CloudWatch Logs, Secrets Manager when used, and S3 for ECR image layers. Supply their endpoint security groups and managed prefix lists to the module. Confirm the target group uses IP targets and has a health check compatible with the service readiness behavior.

## Deployment verification

Apply from the controlled environment repository. Wait for ECS steady state, then verify target health, task count, deployment events, container health, and error logs. Exercise liveness and readiness through the load balancer. Confirm a database connection using the application's least-privilege role and verify that logs contain no credentials.

Check that the running task definition references the reviewed digest. Record the Terraform state version, task definition revision, image digest, and database event state in the deployment evidence.

## Rollback

The ECS circuit breaker rolls back a failed deployment to the last completed deployment. For an application regression after steady state, restore the previous digest in configuration, review the plan, and apply it. Database migrations must remain backward compatible until rollback is no longer required. Do not restore a database merely to roll back application code.

## Database restore

Create a new RDS instance from a selected automated or final snapshot. Never restore over the original instance. Apply equivalent subnet, security-group, encryption, parameter, log, and deletion-protection settings. Validate schema and data with a restricted client, then update the workload through a reviewed configuration change. Retain the old instance until acceptance checks and the recovery window pass.

## Teardown

Scale traffic away and preserve required evidence. Confirm retention obligations and take a manual snapshot when policy requires one. Remove ECR images deliberately. Disable database deletion protection in a separate reviewed apply, then review the destroy plan. Terraform requests the configured final snapshot. Verify the snapshot is available before removing any remaining recovery path. A failed deletion caused by an existing final snapshot name requires preserving or explicitly managing that snapshot, never silently skipping it.
