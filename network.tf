data "aws_region" "current" {}
data "aws_vpc" "existing" { id = var.vpc_id }
data "aws_vpc_endpoint" "s3" { id = var.existing_s3_endpoint_id }
data "aws_prefix_list" "s3" { name = "com.amazonaws.${var.aws_region}.s3" }
data "aws_route_table" "private" {
  for_each       = var.private_route_table_ids
  route_table_id = each.value
}
resource "terraform_data" "connectivity_guard" {
  lifecycle {
    precondition {
      condition     = data.aws_vpc.existing.enable_dns_support && data.aws_vpc.existing.enable_dns_hostnames
      error_message = "PrivateLink requires VPC DNS support and DNS hostnames."
    }
    precondition {
      condition     = data.aws_vpc_endpoint.s3.vpc_id == var.vpc_id && data.aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway" && alltrue([for id in var.private_route_table_ids : contains(data.aws_vpc_endpoint.s3.route_table_ids, id)])
      error_message = "The existing S3 gateway endpoint must cover both effective private route tables; do not overwrite its associations."
    }
  }
}
resource "aws_security_group" "endpoints" {
  name_prefix = "week13-endpoints-"
  description = "Private AWS API endpoints for ECS runtime"
  vpc_id      = var.vpc_id
  tags        = { Name = "week13-endpoints", Project = "SIWES-Week13" }
}
resource "aws_vpc_security_group_ingress_rule" "endpoints_from_ecs" {
  security_group_id            = aws_security_group.endpoints.id
  referenced_security_group_id = aws_security_group.ecs_app.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
resource "aws_vpc_security_group_egress_rule" "ecs_to_endpoints" {
  security_group_id            = aws_security_group.ecs_app.id
  referenced_security_group_id = aws_security_group.endpoints.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
resource "aws_vpc_security_group_egress_rule" "ecs_to_s3" {
  security_group_id = aws_security_group.ecs_app.id
  prefix_list_id    = data.aws_prefix_list.s3.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(["ecr.api", "ecr.dkr", "logs", "secretsmanager"])
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "week13-${each.key}", Project = "SIWES-Week13" }
  depends_on          = [terraform_data.connectivity_guard, aws_vpc_security_group_ingress_rule.endpoints_from_ecs]
}
