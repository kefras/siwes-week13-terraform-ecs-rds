# Week 13 evidence checklist

Status statements are not substitutes for attached evidence. The owner confirmed the live service, target health, database response and no-change plan. All boxes below are deliberately open until the corresponding artifacts are captured and reviewed. Keep raw evidence under ignored `evidence/`; submit only selected redacted copies through an approved channel.

| Item | Suggested private filename | Required observation |
|---|---|---|
| [ ] Identity/context | `screenshots/01-context.png` | us-east-1 and intended account; redact account/user identifiers for public use |
| [ ] Terraform validation | `screenshots/02-validation.png` | configuration valid; correct project directory |
| [ ] Current drift plan | `screenshots/03-no-changes.png` | complete successful No changes result; detailed exit code 0, not failed refresh or old 21-addition plan |
| [ ] ECS service | `screenshots/04-service.png` | desired 2, running 2, pending 0, stable deployment |
| [ ] Task placement | `tasks.json`, `screenshots/05-tasks.png` | running task IDs, actual AZs/private subnets, health and no public IPs |
| [ ] Image version | `screenshots/06-image.png` | task definition references v2; running ECR digest recorded; original v1 preserved |
| [ ] ALB listener | `screenshots/07-listener.png` | internet-facing ALB, both public subnets, HTTP port 80 forwarding to target group |
| [ ] Target health | `targets.json`, `screenshots/08-targets.png` | two healthy IP targets, port 8000 and /health path |
| [ ] Browser application | `screenshots/09-application.png` | actual ALB URL loads the application; no invented screenshots |
| [ ] Live MySQL readiness | `health.json`, `screenshots/10-db-health.png` | HTTP 200 and database=connected at ALB /health |
| [ ] Startup SQL log | `screenshots/11-startup-query.png` | successful TLS SELECT 1 startup message; no credentials/errors containing values |
| [ ] Task configuration | `screenshots/12-config.png` | APP_ENV and secret references, username/password JSON key selectors; never reveal secret contents |
| [ ] IAM role split | `screenshots/13-iam.png` | execution permissions scoped to ECR/log group/secret; separate task role |
| [ ] RDS settings | `screenshots/14-rds.png` | private Multi-AZ database and application SG ingress; record backup limitations honestly |
| [ ] Endpoint connectivity | `screenshots/15-endpoints.png` | four interface services available with private DNS and both AZs; existing S3 gateway associations |
| [ ] Route tables | `screenshots/16-routes.png` | public IGW default route; private S3/local routes with no NAT assumption |
| [ ] Autoscaling configuration | `screenshots/17-scaling-policy.png` | CPU target 70%, min 2/max 4, cooldowns |
| [ ] Cost estimate | `screenshots/18-cost-assumptions.png` | documented rates/730-hour assumption; distinguish estimate from actual bill |
| [ ] Git/CI safety | `screenshots/19-ci-disabled.png` | exact false guards and inherited Git-root review; no claim of a completed CI run |

## Evidence already available locally

- Earlier v2 build log, image-runtime unit test results and disposable MySQL/TLS test summary are historical local-build evidence. [Image record](../IMAGE_PREPARATION.md).
- `evidence/final-review-plan.txt` records this review's failed AWS DNS refresh attempt. Do not submit it as a successful no-change plan.
- Local state contains deployed resource records; never publish the state file as evidence.
- Review [VALIDATION.md](../VALIDATION.md) for actual checks and unresolved evidence gaps.

## Capture and review

1. Use the README's read-only verification commands, recording a timestamp and AWS region. Capture **Win+Shift+S** screenshots to `evidence/screenshots/`.
2. Review each image/text export before sharing. Exclude passwords, access keys, tokens, `.env` values, state, binary plans and credential files. Redact unnecessary account IDs, ARNs, addresses and personal information without concealing the actual health result.
3. Ensure the shown image tag/digest, service, target group and timestamps correspond to the same deployment. Old preparation plans are not current drift evidence.
4. Mark boxes only after capture, redaction and review. No screenshot is marked complete by this documentation task.

## Future CI evidence — not yet completed

- [ ] Dedicated Week 13 Git ownership and intended remote approved; sanitized candidate file list inspected.
- [ ] Encrypted/versioned/private remote state created and original state migrated under separate approval; locking tested.
- [ ] Exact-repository OIDC roles and least-privilege actions tested; no long-lived AWS keys stored.
- [ ] Reviewer-protected plan/production Environments and main branch restrictions verified.
- [ ] Explicit disabled guards changed only through approved review.
- [ ] Actual PR plan, required approval, merged apply and subsequent no-change plan captured.

Do not fabricate these artifacts or enable CI merely to fill the checklist. A load-induced scale-out, RDS failover, backup restore or secret-rotation rollout is also unverified unless separately authorized and observed.
