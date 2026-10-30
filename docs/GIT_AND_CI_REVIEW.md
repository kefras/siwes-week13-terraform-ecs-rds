# Git ownership and CI review

Review date: 30 October 2026 (Africa/Lagos). Read-only Git inspection and local workflow-source review; no Git configuration changes, remote inspection through GitHub, commits or pushes.

## Git ownership and inherited repository

| Check | Result |
|---|---|
| Working directory | `C:/Users/HP 840 G7/Documents/SIWES1-Terraform/week13-terraform-ecs-rds` |
| Filesystem owner | `ETIKU\ETIKU` |
| Git root | `C:/Users/HP 840 G7` |
| Git metadata | `C:/Users/HP 840 G7/.git` |
| Inherited origin, fetch and push | `https://github.com/kefras/Kefas-portfolio.git` |
| Configured author name | Kefas Etiku Francis; inherited global configuration, not proof of GitHub ownership |
| Project tracked paths | `git ls-files -- .` returned no Week 13 paths |

The portfolio remote is unrelated to the Week 13 deployment. Local filesystem ownership and configured author identity do not establish ownership or write permission for a GitHub destination. No dedicated remote's existence or account access has been verified.

## Proposed repository isolation — manual approval still needed

1. Confirm the owner/account and desired private or public destination, for example `week13-terraform-ecs-rds`. The name is a proposal, not a created repository.
2. Prefer making this existing project folder its own repository after explicit approval; do not move/copy state into a new empty Terraform root and do not alter the home portfolio remote. The live Terraform state stays in its current local ownership until a separate backend migration is approved.
3. Inspect `.gitignore`, sanitized `terraform.tfvars.example`, provider locks and the exact candidate source/docs/workflow list. Confirm no parent-tracked sensitive files need a separate remediation. Ignore rules are not a secret-history cleanup tool.
4. Only after approval, establish a project-local Git root and its intended remote. Stage named source/docs files explicitly; avoid home-root `git add .`. Review staged diffs and run a secret scan before any commit/publication.
5. Confirm repository visibility, reviewer features and access permissions before proposing CI activation. Do not inherit portfolio credentials/settings by assumption.

No initialization, staging, commit, remote change, repository creation or push was executed in this review.

## Workflow review and disabled state

| Workflow | Observed design | Present status |
|---|---|---|
| `terraform-validate.yml` | checkout, Terraform 1.16.6, fmt check, backend-disabled init with readonly lock, validate; contents read only | Credential-free source validation; no cloud apply |
| `terraform-plan.yml` | same-repository PR design, OIDC plan role, terraform-plan Environment, shared concurrency, locked backend, state-address checks, preservation guard and PR comment | Job explicitly `if: ${{ false }}`; cannot run an AWS plan from a repository variable alone |
| `terraform-apply.yml` | merged-main association check, terraform-production Environment, OIDC apply role, fresh plan and exact saved-plan apply | Both merged-pr and apply jobs explicitly `if: ${{ false }}` |

These local false guards prevent execution when this reviewed workflow source is used. Remote GitHub configuration and any unrelated repository workflows were not inspected or changed. No CI execution or Environment approval is claimed. The local AWS profile is not embedded into these workflows.

## Controls retained for future review

- No `pull_request_target` execution of untrusted PR code with AWS credentials; fork PRs would receive only credential-free validation under the intended design.
- OIDC audience and exact repository/environment subjects replace long-lived AWS credentials. Production Environment must be restricted to main because an environment subject alone is not a branch restriction.
- S3 backend requires encryption and native lockfile locking; startup checks require existing RDS/ECR/original SG state addresses. The original local state has not been migrated.
- The plan guard rejects deletion/replacement and changes to protected data/registry/original SG resources. Shared concurrency serializes state access; state and binary plans are not uploaded as artifacts.
- `ci/bootstrap` is a separate Terraform root; approving app deployment does not approve backend/IAM provisioning.

## Findings and remaining work

1. **Dedicated repository prerequisite:** no intended Week 13 remote/ownership has been confirmed. Workflows assume the checkout root is this Terraform root; adjust paths if an approved repository has a different layout.
2. **Backend/IAM prerequisite:** local state is active. Bootstrap, state migration, locking and OIDC roles are source scaffolding, not a verified live CI system. Policy behavior must be tested without substituting AdministratorAccess.
3. **Approval prerequisite:** create protected Environments, required reviewers/prevent self-review, main-only production rules, branch protection and repository variables only under separate approval. Check GitHub plan/visibility support first.
4. **Supply chain:** actions use version tags rather than immutable commit SHAs. Review and pin action revisions before activation. Terraform provider locks remain publishable.
5. **Plan disclosure:** PR comments include plan text and truncate at 55 KB. Future resource attributes could contain sensitive values; review/redact output and access controls before enabling comments. No plan/state artifact is uploaded, but that does not make arbitrary plan comments safe.
6. **Apply approval semantics:** the Environment approval authorizes the merged commit before the job creates its fresh plan; it is not a second approval of that newly generated binary plan. If approval of exact plan content is required, redesign that workflow under separate review.
7. **CI completion:** no OIDC run, CI apply or required-reviewer event has been demonstrated. Keep explicit false guards until all prerequisites and a controlled test are approved.
