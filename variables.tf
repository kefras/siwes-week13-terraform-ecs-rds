
variable "vpc_id" {
  description = "Existing AWS VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs in different Availability Zones"
  type        = list(string)
}

variable "app_security_group_ids" {
  description = "Security groups allowed to access RDS"
  type        = list(string)
}
