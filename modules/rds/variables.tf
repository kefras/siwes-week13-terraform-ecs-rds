variable "subnet_ids" {
  description = "Private subnet IDs for RDS"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Application security groups allowed to access MySQL"
  type        = list(string)
}

variable "db_username" {
  description = "Database administrator username"
  type        = string
  default     = "adminuser"
}

variable "db_name" {
  description = "Initial MySQL database name"
  type        = string
  default     = "appdb"
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}


variable "vpc_id" {
  description = "VPC where the RDS database will be deployed"
  type        = string
}
