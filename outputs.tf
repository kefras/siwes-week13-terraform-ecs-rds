
output "database_endpoint" {
  value = module.rds.db_endpoint
}

output "database_port" {
  value = module.rds.db_port
}

output "database_secret_arn" {
  value = module.rds.db_secret_arn
}


output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.ecs_app.repository_url
}

output "alb_security_group_id" {
  description = "Security group for ALB"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "Security group for ECS Fargate tasks"
  value       = aws_security_group.ecs_app.id
}

output "rds_security_group_id" {
  description = "Security group for RDS MySQL"
  value       = module.rds.db_security_group_id
}
