output "alb_dns_name" { value = module.ecs.alb_dns_name }
output "application_url" { value = "http://${module.ecs.alb_dns_name}" }
output "ecs_cluster_name" { value = module.ecs.cluster_name }
output "ecs_service_name" { value = module.ecs.service_name }
output "target_group_arn" { value = module.ecs.target_group_arn }
output "log_group_name" { value = module.ecs.log_group_name }
output "container_image_uri" { value = "${aws_ecr_repository.ecs_app.repository_url}:v2" }
