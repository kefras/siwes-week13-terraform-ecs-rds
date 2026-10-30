variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "public_subnet_ids" {
  description = "Verified IGW-routed public subnets in two AZs; never private subnet IDs."
  type        = list(string)
  default     = ["subnet-041b38a966c203677", "subnet-0a0c5a8493b2f0e05"]
  validation {
    condition     = length(distinct(var.public_subnet_ids)) == 2
    error_message = "Supply exactly two different public subnets."
  }
}
variable "private_route_table_ids" {
  description = "Effective route tables for the private subnets, including main-table fallback."
  type        = set(string)
}
variable "existing_s3_endpoint_id" {
  description = "Existing S3 gateway endpoint. Preserve its existing route-table associations."
  type        = string
}
variable "app_env" {
  type    = string
  default = "production"
}
variable "database_kms_key_arn" {
  description = "Customer managed secret key ARN only; null for AWS-managed aws/secretsmanager."
  type        = string
  default     = null
}
variable "ecs_desired_count" {
  type    = number
  default = 2
}
variable "ecs_min_capacity" {
  type    = number
  default = 2
}
variable "ecs_max_capacity" {
  type    = number
  default = 4
}
