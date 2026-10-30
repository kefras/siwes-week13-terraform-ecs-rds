> Historical image-preparation record. The owner subsequently verified the deployed v2 service and live database health. Its earlier no-push/no-deployment statements and 21-addition plan describe that preparation stage only; current status is in [README](README.md) and [VALIDATION](VALIDATION.md).

# v2 Docker image preparation

## Completed

- Built locally: `week13-ecs-app:v2`, Linux/amd64, nonroot `appuser`.
- Local image ID: `sha256:302c6e56314313c52e49afa1a50b108fb8596a5889ab5b643b90acb146697c6e`. Local image ID/index digest must not be confused with a future ECR repository digest.
- Three unit tests passed **inside the built Python 3.12 image**; imports, valid baked RDS CA bundle, nonroot execution and `pip check` passed.
- Real disposable MySQL 8.4 test passed with secure transport required: app startup and `SELECT 1` over certificate/hostname-verified TLS, running nonroot with a read-only filesystem.
- The exact ECS health command extracted from `modules/ecs/main.tf` passed for the connected database. Stopping the test database produced HTTP 503 and a failing probe. Disposable test containers/network/certificates were removed; downloaded local images are retained.
- Source inspection confirms ECS `secrets` maps the existing RDS secret's JSON `username`/`password` keys into `DB_USERNAME`/`DB_PASSWORD`, and FastAPI reads those exact variables. Neither image nor plain task environment contains database credentials. Local integration uses disposable test-only credentials and a test CA; it does not retrieve AWS secrets or prove RDS connectivity.
- Health is configured by ECS (Python stdlib probe, port 8000 `/health`, requires `database=connected`; interval 30s, timeout 5s, retries 3, start period 60s). Dockerfile does not define a separate image HEALTHCHECK; ECS supplies it. Local tests execute that same command directly.

## Terraform

Reference: `178777954852.dkr.ecr.us-east-1.amazonaws.com/week13-ecs-app:v2`.
The earlier v1 image data lookup is removed; `container_image_uri` replaces the not-yet-applied `image_digest` output. Planning uses the explicit v2 tag so it succeeds before any push. This is not a remote existence check or digest pin. Record/verify the pushed ECR digest before later deployment; do not overwrite v2 after approval.

`terraform fmt -recursive`, `terraform validate` and AWS-backed `terraform plan` passed.
Final plan: **21 to add, 0 to change, 0 to destroy**; preservation guard: 21 creates / 11 unchanged existing resources.
Full plan: `evidence/plan-v2.txt`; saved binary: `evidence/week13-v2.tfplan` (ignored).
Existing state SHA-256 remains `f690fbe102b10a2b076bb361fec06c4c2ce47b14be52abda2ec653200b264de8`.

## Not executed

No push, apply, destroy, remote-state migration, AWS resource modifications, state modifications or CI/CD enabling. Existing ECR v1 and local v1 tag were not retagged, overwritten or deleted. Live RDS/Secrets Manager retrieval remains unverified until separately approved deployment.

## Future push only after separate approval — PowerShell

```powershell
$registry = '178777954852.dkr.ecr.us-east-1.amazonaws.com'
aws ecr get-login-password --profile siwes-terraform --region us-east-1 | docker login --username AWS --password-stdin $registry
if ($LASTEXITCODE -ne 0) { throw 'ECR login failed' }
docker tag week13-ecs-app:v2 "$registry/week13-ecs-app:v2"
if ($LASTEXITCODE -ne 0) { throw 'Tag failed' }
docker push "$registry/week13-ecs-app:v2"
```

After the approved push, re-plan/review before seeking deployment approval. No command in this report was used to push during preparation.

## Reproduce local integration test

```powershell
& evidence/test-venv/Scripts/python.exe app/tests/local_mysql.py
```

Requires Docker and host Python `cryptography`. Build log: `evidence/build-v2.log`. Local integration log: `evidence/local-mysql-v2.log`.
