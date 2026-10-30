$ErrorActionPreference = 'Stop'
$addresses = terraform state list
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect state' }
foreach ($required in @('module.rds.aws_db_instance.this', 'aws_ecr_repository.ecs_app', 'aws_security_group.ecs_app', 'aws_security_group.alb')) {
    if ($required -notin $addresses) { throw "Required existing resource absent from state: $required. Stop; never apply to an empty or wrong state." }
}
