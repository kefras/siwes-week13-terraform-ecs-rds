# SIWES technical report: Week 13

**Student:** Kefas Etiku Francis  
**Project:** Terraform ECS Fargate with private Multi-AZ RDS MySQL  
**Scope:** Labs 13.3, 13.4, 13.5 and CI preparation for 13.6  
**Documentation review:** 30 October 2026, Africa/Lagos  
**Environment:** AWS us-east-1; existing Week 13 Terraform project

## Executive summary

This project expresses the container application tier as reusable Terraform, integrates it with the existing private MySQL data layer and uses AWS-managed runtime secret injection. A public Application Load Balancer forwards HTTP traffic to two Fargate tasks in private subnets. Private service endpoints allow image pulls, secret retrieval and logging without a NAT internet route.

The project owner confirmed the deployed service has two running tasks, two healthy ALB targets, a live MySQL-connected health response and a no-change Terraform plan. Local state also records the deployed resources. During this documentation pass, formatting and configuration validation passed. A fresh cloud plan attempt encountered an AWS DNS-resolution error, so the earlier owner-verified no-change result is not represented as independently repeated here. See [current validation](../VALIDATION.md).

## Objectives and lab mapping

| Lab | Objective | Evidence and completion boundary |
|---|---|---|
| 13.3 | Understand cluster, task definition, service and target group | Resources implemented in `modules/ecs`; diagram and source inspection document their roles |
| 13.4 | Deploy two private Fargate tasks behind an ALB; CPU scaling | Owner verified running service/healthy targets; scaling configured min 2, max 4, target 70%; no load-driven scale event claimed |
| 13.5 | Separate configuration and secrets; prove MySQL connectivity | ECS secret JSON keys inject credentials; startup and health run real TLS `SELECT 1`; local integration tested and owner verified live health |
| 13.6 | Plan on PR and apply after merge with approval | Workflows and OIDC/backend scaffolding reviewed; cloud jobs explicitly disabled; remote backend migration and actual CI run remain manual approved work |

This distinguishes a working AWS deployment from an operational CI pipeline. Lab 13.6 is prepared in code, not falsely recorded as a completed deployment through GitHub Actions.

## Existing infrastructure and design

The project reuses VPC `vpc-08cb55538e782f57c`, its public/private subnets, RDS `week13-mysql-db`, ECR `week13-ecs-app`, security groups and the existing S3 gateway endpoint. Terraform resource addresses and state ownership are retained. The database is private, encrypted and Multi-AZ. Image `v2` is selected; original `v1` remains preserved.

[Architecture source](architecture.mmd) and the [README diagram](../README.md#architecture) show the deployed data plane. The ALB spans two public subnets with an Internet Gateway default route. Tasks use two private subnets with public IP assignment disabled. The database diagram intentionally does not assume the writer's current AZ; a failover can change it.

The ECS cluster is the logical grouping, the task definition describes the image/resources/configuration/roles, and the service maintains tasks and registers their private IP targets. A rolling deployment circuit breaker can roll back an unhealthy deployment. Task count is initially two, then controlled by target-tracking autoscaling; Terraform ignores desired-count drift caused by scaling. Platform 1.4.0 supports JSON-key secret injection. Each task uses 256 CPU units and 512 MiB memory by default.

## Private networking and access controls

Earlier route inspection found no NAT/default internet route in the task subnets. Assuming internet access would leave Fargate unable to fetch its image or secret. The chosen design reuses the S3 gateway endpoint for image layers and adds interface endpoints for ECR API, ECR Docker, CloudWatch Logs and Secrets Manager, each in both private subnets with private DNS. VPC DNS and S3 route associations are configuration preconditions.

Security groups permit public HTTP to the ALB, ALB-to-task TCP 8000, task-to-RDS TCP 3306, task-to-endpoint TCP 443 and HTTPS to the regional S3 prefix list. The RDS SG accepts the application SG rather than public addresses. Tasks cannot fetch arbitrary internet dependencies, so Python packages and CA certificates are installed during the image build. The endpoints' default policies and the execution role's scoped IAM permissions are separate network and authorization controls.

The execution role pulls only the intended ECR repository, writes the application log group and reads the selected secret. Its authorization-token action needs a wildcard resource. The task role has no application AWS API policy. Runtime credentials are still visible inside the application environment to privileged runtime tooling; environment injection is not equivalent to a secret being inaccessible after startup.

## Configuration, secret injection and database test

Nonsensitive settings include APP_ENV, database hostname/port/name and the CA path. ECS reads `username` and `password` from the RDS-managed secret and injects DB_USERNAME and DB_PASSWORD. Terraform handles secret references, not the password value, and local development selects the named AWS profile through the environment; CI source uses OIDC rather than the local profile.

FastAPI creates a verified SSL context from the RDS CA bundle and opens PyMySQL connections using the injected values. Startup retries a real `SELECT 1` and fails if connectivity cannot be established. Each readiness request performs another real query. A successful request returns `database=connected`; database errors produce a redacted HTTP 503. The ECS probe checks that JSON field as well as HTTP success, preventing the earlier static health endpoint from masquerading as integration evidence.

The local v2 image was built and tested as Linux/amd64, nonroot, with a read-only runtime filesystem. Three unit tests passed in the built image. A disposable MySQL 8.4 test required TLS, verified real SQL connectivity and confirmed database shutdown causes 503/probe failure. Those local tests are historical build evidence; they are not substituted for the owner's subsequent live RDS verification.

## Operational verification and evidence quality

Evidence should join four independent observations: ECS running count/deployment, ALB target health, the application database response and Terraform's drift result. A healthy target alone does not prove secure DB transport, a no-change plan does not prove application health, and a configured CPU policy does not prove an actual scaling event. Task metadata should demonstrate AZ placement, private addressing and the running image digest.

The [checklist](EVIDENCE_CHECKLIST.md) defines filenames, expected outcomes and missing evidence. It intentionally leaves screenshots unmarked until captured and reviewed. Runtime secret values, full state and binary plans must not be published. The review's new failed plan is retained privately as a diagnostic, not mislabeled as successful deployment evidence.

## Cost assessment

At 730 hours per month, the illustrative additional container/network baseline is approximately $100.15: endpoints $58.40, two Fargate tasks $18.02, ALB base $16.43 and an assumed two public ALB IPv4 addresses $7.30. The [README cost table](../README.md#costs) provides rates and official pricing links. This estimate excludes existing Multi-AZ RDS/storage, Secrets Manager, ECR, ALB LCUs, logs, endpoint data and transfer. It is not a billing export. Autoscaling and rolling deployments can increase task charges. Endpoint and ALB hourly costs continue without application traffic.

## Limitations and improvements requiring separate approval

The lab is not presented as production-hardened. The public listener uses HTTP without authentication/WAF; the app uses a database master user; backups and AWS deletion protection remain disabled; Terraform state is local. Multi-AZ is availability protection, not recovery from logical deletion. ECR tags and package ranges remain mutable, and seven-day logs do not provide an audit archive. There is no evidenced restore exercise, load-driven autoscaling test or alerting setup.

Future reviewed work could add HTTPS/domain/authentication, a least-privilege SQL user, tested backups/retention, image/dependency pinning and scanning, monitoring, and approved encrypted remote state. No production setting was changed for this report.

## Git and CI review

Filesystem ownership is `ETIKU\ETIKU`. Git inspection resolves the root to the user's home directory, with the inherited portfolio remote. No Week 13 paths are tracked by that repository. A separate project-root repository is proposed only after confirming ownership and intended GitHub destination; no initialization, remote change or publication occurred.

Cloud plan and apply jobs now have explicit false guards. Credential-free validation remains available if the workflows are later placed in an appropriate repository. A future pipeline requires state migration, exact repository/environment OIDC trust, least-privilege policy tests, required reviewers, main-only production deployments and protected branches. [Git and CI review](GIT_AND_CI_REVIEW.md) lists the findings, including mutable action tags and potential plan-comment disclosure.

## Cleanup and learning outcome

No cleanup was executed. Teardown requires approved targeting of only the new compute/network tier, review of every deletion, evidence retention and confirmation that existing data/registry/network resources and their state remain intact. An unqualified root destroy is unsuitable. The [cleanup procedure](../README.md#cleanup-separate-approval-required) describes a review-only plan, not unattended deletion.

The project demonstrates modular infrastructure, private container networking, IAM role separation, runtime secrets, honest database readiness and the difference between deployment automation code and a verified operating pipeline. The remaining submission work is to capture/redact evidence, confirm the final no-change plan when DNS is available, and obtain separate approval for any future repository or CI activation.
