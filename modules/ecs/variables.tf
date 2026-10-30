variable "name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "public_subnet_ids" { type = list(string) }
variable "task_security_group_id" { type = string }
variable "alb_security_group_id" { type = string }
variable "image" { type = string }
variable "ecr_repository_arn" { type = string }
variable "database_host" { type = string }
variable "database_port" { type = number }
variable "database_name" { type = string }
variable "database_secret_arn" { type = string }
variable "database_kms_key_arn" {
  type    = string
  default = null
}
variable "app_env" {
  type    = string
  default = "production"
}
variable "desired_count" {
  type    = number
  default = 2
}
variable "min_capacity" {
  type    = number
  default = 2
}
variable "max_capacity" {
  type    = number
  default = 4
}
variable "container_port" {
  type    = number
  default = 8000
}
variable "cpu" {
  type    = number
  default = 256
}
variable "memory" {
  type    = number
  default = 512
}
variable "health_check_path" {
  type    = string
  default = "/health"
}
variable "log_retention_days" {
  type    = number
  default = 7
}
