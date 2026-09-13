# awsbox

`awsbox` is a Terraform foundation for one private ECS Fargate HTTP workload and its PostgreSQL data boundary. It gives a service team a reviewable starting point for the controls that are easy to omit when assembling ECR, ECS, IAM, networking, logs, and RDS independently.

The intended user already has a VPC, at least two private subnets, an Application Load Balancer security group, and an IP target group. The module creates no public ingress. It accepts only a digest-pinned image, keeps the task and execution roles separate, permits database traffic only from the task security group, and enables database encryption, backups, a final snapshot, and deletion protection by default.

## Scope

The module creates:

- an immutable, encrypted ECR repository with scan-on-push and untagged-image expiry;
- an ECS cluster, hardened ARM64 Fargate task, and circuit-breaker service in private subnets;
- separate empty application and narrowly scoped execution roles;
- CloudWatch application logs with bounded retention;
- service and database security groups with source-specific rules; and
- encrypted RDS PostgreSQL with an AWS-managed master password, Multi-AZ default, storage autoscaling, backups, logs, and deletion safeguards.

It does not create a VPC, NAT gateway, VPC endpoints, load balancer, TLS certificate, DNS, application secrets, database schema, autoscaling policy, alert receiver, or CI deployment role. Those decisions depend on the consumer environment. It does not apply infrastructure during validation.

## Adoption

Copy `examples/consumer` into the environment repository, replace every example identifier, and pin the module source to a reviewed commit. Private subnets need approved paths to ECR, CloudWatch Logs, Secrets Manager when used, and S3 for ECR image layers. Pass interface endpoint security groups and managed prefix lists explicitly. The module deliberately has no unrestricted internet egress. Add any NAT-bound or external destination rules in the environment after a separate review.

Build and scan the application image, push it using a unique tag, resolve its registry digest, and pass the digest form to `image`. Pass its repository ARN separately so the execution role can pull only from the real source. The module-created repository is exposed for publication, but the first deployment normally uses an image prepared in an existing bootstrap repository. Subsequent changes can use this repository. This explicit two-phase path avoids a Terraform dependency cycle.

The task receives database host metadata but no password. Attach a narrow policy to `task_role_arn` only if the application should read the RDS-managed secret. Prefer a separate migration task and least-privilege database roles over running permanently as the master user.

Before any apply, review the saved plan, expected monthly AWS costs, subnet egress design, RDS class and storage, Multi-AZ requirement, backup retention, alarms, and restore procedure. Run:

```text
make ci
terraform plan -out=review.tfplan
terraform show review.tfplan
```

## Tradeoffs

The task drops Linux capabilities, uses numeric user `10001:10001`, and marks its root filesystem read-only. The selected image must support those constraints and provide `wget` for the local health command. ARM64 reduces the supported image set, so publish a matching manifest before deployment.

HTTPS endpoint egress and database egress are explicit. DNS traffic is provided by the VPC resolver outside security-group filtering. Workloads needing other outbound destinations or ports must add reviewed rules in their environment rather than receiving unrestricted egress here.

RDS uses a stable final snapshot identifier. A repeated destroy after a partial teardown may require an operator to preserve or rename the existing snapshot before retrying. This friction is intentional. See `docs/runbook.md` for deployment, rollback, restore, and teardown guidance.

## Validation

`make ci` checks formatting, initializes without a backend, validates the root and consumer example, and runs native Terraform tests with a mocked AWS provider. Tests cover security and recovery defaults plus rejection of mutable images, one-subnet placement, and an invalid storage ceiling. Provider mocking proves configuration logic without credentials or paid resources. It is not evidence of a live AWS deployment.
