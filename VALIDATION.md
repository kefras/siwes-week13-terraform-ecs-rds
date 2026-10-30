# Documentation review and validation

Review date: 30 October 2026, Africa/Lagos. Scope is documentation, ignore rules and local disabling of cloud workflow jobs in the existing Week 13 folder. No application or Terraform production configuration was changed.

## Current deployment status

The owner confirms two ECS tasks running, both ALB IP targets healthy, live MySQL health connected and a successful no-change Terraform plan. Local state serial 52 records 32 managed instances (including the Terraform connectivity guard) and the deployed v2/ALB outputs. This is consistent with a completed deployment, but state alone is not a live AWS health check.

## Checks performed in this review

| Check | Result |
|---|---|
| `terraform fmt -check -recursive` | Passed; no Terraform files reformatted |
| `terraform validate -no-color` | Passed |
| Fresh `terraform plan -detailed-exitcode` | **Could not complete**, exit 1: AWS DNS lookup failure, including `application-autoscaling.us-east-1.amazonaws.com` |
| ECS/ALB/HTTP rechecks in that command sequence | Not executed after the plan failure; no new live-health claim made |
| Owner's earlier no-change/live verification | Recorded as owner-confirmed, not overwritten by the failed refresh attempt |
| Git root, remote, project tracked files and owner | Inspected; home Git root, inherited portfolio origin, no tracked Week 13 paths; filesystem owner ETIKU\ETIKU |
| Terraform, application, provider lock, tfvars and state content hashes | Unchanged from this review's baseline |
| Markdown documents, local links and encoding | Passed: 6 documents, 24 local links/anchors, balanced fences; no damaged Unicode |
| Mermaid architecture | Parsed with Mermaid; standalone source matches README after line-ending normalization |
| Workflow YAML and disable assertions | Passed: 3 workflows; AWS plan and both apply-workflow jobs explicitly disabled |
| Ignore-rule fixtures | Passed: 22 excluded sensitive/generated paths; 11 allowed source/example/lock paths |
| Documented PowerShell syntax | Parsed without executing deployment or cleanup commands |

The plan failure is a connectivity limitation, not evidence of Terraform drift or a successful no-change plan. Diagnostic output is private at `evidence/final-review-plan.txt`. Re-run the README read-only checks when AWS DNS connectivity is restored. No retry with `-refresh=false` is presented as a substitute for a live drift check.

## Deliverables

- README rewritten for the deployed system, with deployment/change-control procedure, read-only verification, cost assumptions, real security limitations and approval-only selective cleanup.
- Standalone `docs/architecture.mmd` matches the README Mermaid block and excludes undeployed CI/backend components.
- SIWES technical report maps lab outcomes and marks lab 13.6 as prepared, not live-verified.
- Evidence checklist contains expected observations and future CI evidence; screenshots are not falsely marked captured.
- Git/CI review records inherited ownership/remote and proposes isolation only after approval.
- `.gitignore` expanded; sanitized `terraform.tfvars.example` added without modifying real variables. Historical `IMAGE_PREPARATION.md` labeled as a prior stage.
- AWS-authenticated PR-plan job and both apply-workflow jobs explicitly use false guards. Credential-free validation retained. Remote GitHub variables/settings were not inspected or changed.

## Preservation record

At review start and after documentation changes, the local state SHA-256 is:

`7555ff091e5aad5cfc7b6243c2122919fc346c1fbeabeda0831441c8021dd36f`

Source/state checksums are recorded privately in `evidence/documentation-baseline.json`. Original RDS/ECR/VPC resources, active Terraform state, application source, provider locks and production settings remain unchanged. No apply/destroy, cloud modifications, image push, backend migration, Git initialization/commit/push or CI enabling occurred.

## Remaining manual steps

1. Restore AWS DNS connectivity and repeat the read-only no-change plan and health commands if fresh independently captured evidence is required.
2. Capture and redact the checklist artifacts; a real scaling/load/restore/rotation test requires its own authorization and observations.
3. Confirm intended Week 13 repository ownership, destination and visibility before any local Git initialization or publication. Do not use the inherited portfolio remote.
4. Review existing security limitations and costs; any HTTPS, database-user/backup, monitoring or other hardening is a separate approved production change.
5. Keep cloud CI disabled. Backend/OIDC provisioning, state migration, policy tests, protected Environments/branch rules and activation require separate approval; no workflow run or remote approval gate is claimed.

## Reproducing documentation checks

Run from this project root:

```powershell
npm install --prefix evidence/docs-tools --no-save --ignore-scripts mermaid markdown-it yaml jsdom
node scripts/validate_docs.mjs
```

Tools and generated previews/results remain inside ignored `evidence/`. The validator checks local links and anchors, Markdown encoding/fences, Mermaid syntax/source equality and workflow YAML/disabled guards. It does not verify remote URL availability, visual browser rendering, GitHub-hosted execution or cloud health. PowerShell documentation blocks were separately parsed with the built-in PowerShell language parser without execution.
