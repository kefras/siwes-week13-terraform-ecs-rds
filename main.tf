provider "aws" {
  region = var.aws_region
  # Local profile comes from AWS_PROFILE; GitHub uses OIDC environment credentials.
}

# Preserve these addresses and all existing RDS inputs.
resource "aws_security_group" "ecs_app" {
  name_prefix = "week13-ecs-app-"
  description = "Security group for Week 13 ECS application"
  vpc_id      = var.vpc_id
  tags        = { Name = "week13-ecs-app-sg", Project = "SIWES-Week13" }
}

module "rds" {
  source                     = "./modules/rds"
  vpc_id                     = var.vpc_id
  subnet_ids                 = var.private_subnet_ids
  allowed_security_group_ids = concat([aws_security_group.ecs_app.id], var.app_security_group_ids)
  db_name                    = "appdb"
  db_username                = "adminuser"
  multi_az                   = true
}

module "ecs" {
  source                 = "./modules/ecs"
  name                   = "week13-ecs-app"
  vpc_id                 = var.vpc_id
  private_subnet_ids     = var.private_subnet_ids
  public_subnet_ids      = var.public_subnet_ids
  task_security_group_id = aws_security_group.ecs_app.id
  alb_security_group_id  = aws_security_group.alb.id
  image                  = "${aws_ecr_repository.ecs_app.repository_url}:v2"
  ecr_repository_arn     = aws_ecr_repository.ecs_app.arn
  database_host          = module.rds.db_endpoint
  database_port          = module.rds.db_port
  database_name          = "appdb"
  database_secret_arn    = module.rds.db_secret_arn
  database_kms_key_arn   = var.database_kms_key_arn
  app_env                = var.app_env
  desired_count          = var.ecs_desired_count
  min_capacity           = var.ecs_min_capacity
  max_capacity           = var.ecs_max_capacity
  depends_on             = [aws_vpc_endpoint.interface, aws_vpc_security_group_egress_rule.ecs_to_endpoints, aws_vpc_security_group_egress_rule.ecs_to_s3, aws_vpc_security_group_egress_rule.ecs_to_rds, aws_vpc_security_group_egress_rule.alb_to_ecs, aws_vpc_security_group_ingress_rule.ecs_from_alb]
}
