
resource "aws_security_group" "alb" {
  name_prefix = "week13-alb-"
  description = "Security group for Week 13 application load balancer"
  vpc_id      = var.vpc_id

  tags = {
    Name    = "week13-alb-sg"
    Project = "SIWES-Week13"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80

  description = "Allow HTTP access to ALB"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.ecs_app.id

  ip_protocol = "tcp"
  from_port   = 8000
  to_port     = 8000

  description = "Allow ALB to reach ECS containers"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs_app.id
  referenced_security_group_id = aws_security_group.alb.id

  ip_protocol = "tcp"
  from_port   = 8000
  to_port     = 8000

  description = "Allow application traffic from ALB only"
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_rds" {
  security_group_id            = aws_security_group.ecs_app.id
  referenced_security_group_id = module.rds.db_security_group_id

  ip_protocol = "tcp"
  from_port   = 3306
  to_port     = 3306

  description = "Allow ECS containers to access MySQL RDS"
}
