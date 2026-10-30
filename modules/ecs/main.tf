terraform {
  required_providers { aws = { source = "hashicorp/aws" } }
}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_subnet" "public" {
  for_each = toset(var.public_subnet_ids)
  id       = each.value
}
data "aws_route_table" "public" {
  for_each  = toset(var.public_subnet_ids)
  subnet_id = each.value
}
data "aws_subnet" "private" {
  for_each = toset(var.private_subnet_ids)
  id       = each.value
}
locals {
  tags           = { Project = "SIWES-Week13", Name = var.name }
  ecs_source_arn = "arn:${data.aws_partition.current.partition}:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
}
resource "aws_ecs_cluster" "this" {
  name = var.name
  tags = local.tags
}
resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}
data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [local.ecs_source_arn]
    }
  }
}
resource "aws_iam_role" "execution" {
  name               = "${var.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = local.tags
}
resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  # The app calls MySQL, not AWS APIs. No application AWS permissions.
  tags = local.tags
}
data "aws_iam_policy_document" "execution" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
    resources = [var.ecr_repository_arn]
  }
  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.database_secret_arn]
  }
  dynamic "statement" {
    for_each = var.database_kms_key_arn == null ? [] : [var.database_kms_key_arn]
    content {
      actions   = ["kms:Decrypt"]
      resources = [statement.value]
      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["secretsmanager.${data.aws_region.current.region}.amazonaws.com"]
      }
    }
  }
}
resource "aws_iam_role_policy" "execution" {
  name   = "runtime-access"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution.json
}
resource "aws_lb" "this" {
  name                       = var.name
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [var.alb_security_group_id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true
  tags                       = local.tags
  lifecycle {
    precondition {
      condition     = length(distinct([for s in data.aws_subnet.public : s.availability_zone])) >= 2 && alltrue([for s in data.aws_subnet.public : s.vpc_id == var.vpc_id])
      error_message = "ALB subnets must belong to this VPC and span two AZs."
    }
    precondition {
      condition     = alltrue([for t in data.aws_route_table.public : anytrue([for r in t.routes : r.cidr_block == "0.0.0.0/0" && startswith(coalesce(r.gateway_id, "none"), "igw-")])])
      error_message = "Each public subnet must have a default route directly to an Internet Gateway."
    }
  }
}
resource "aws_lb_target_group" "this" {
  name                 = var.name
  vpc_id               = var.vpc_id
  target_type          = "ip"
  port                 = var.container_port
  protocol             = "HTTP"
  deregistration_delay = 30
  health_check {
    path                = var.health_check_path
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
  tags = local.tags
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  container_definitions = jsonencode([{
    name                   = "app"
    image                  = var.image
    essential              = true
    readonlyRootFilesystem = true
    portMappings           = [{ containerPort = var.container_port, protocol = "tcp" }]
    environment = [
      { name = "APP_ENV", value = var.app_env },
      { name = "DB_HOST", value = var.database_host },
      { name = "DB_PORT", value = tostring(var.database_port) },
      { name = "DB_NAME", value = var.database_name },
      { name = "DB_SSL_CA", value = "/app/certs/global-bundle.pem" },
      { name = "PYTHONDONTWRITEBYTECODE", value = "1" }
    ]
    secrets = [
      { name = "DB_USERNAME", valueFrom = "${var.database_secret_arn}:username::" },
      { name = "DB_PASSWORD", valueFrom = "${var.database_secret_arn}:password::" }
    ]
    healthCheck = {
      command  = ["CMD", "python", "-c", "import json,urllib.request; result=json.load(urllib.request.urlopen('http://127.0.0.1:${var.container_port}${var.health_check_path}', timeout=4)); assert result.get('database') == 'connected'"]
      interval = 30, timeout = 5, retries = 3, startPeriod = 60
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this.name
        awslogs-region        = data.aws_region.current.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
  tags = local.tags
}
resource "aws_ecs_service" "this" {
  name                               = var.name
  cluster                            = aws_ecs_cluster.this.id
  task_definition                    = aws_ecs_task_definition.this.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0"
  availability_zone_rebalancing      = "ENABLED"
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 90
  wait_for_steady_state              = true
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.task_security_group_id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "app"
    container_port   = var.container_port
  }
  lifecycle {
    ignore_changes = [desired_count]
    precondition {
      condition     = length(distinct([for s in data.aws_subnet.private : s.availability_zone])) >= 2 && alltrue([for s in data.aws_subnet.private : s.vpc_id == var.vpc_id])
      error_message = "Private task subnets must span two AZs in this VPC."
    }
    precondition {
      condition     = var.min_capacity >= 0 && var.min_capacity <= var.desired_count && var.desired_count <= var.max_capacity
      error_message = "Require 0 <= min_capacity <= desired_count <= max_capacity."
    }
  }
  tags       = local.tags
  depends_on = [aws_lb_listener.http, aws_iam_role_policy.execution]
}
resource "aws_appautoscaling_target" "this" {
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name}-cpu70"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace
  target_tracking_scaling_policy_configuration {
    target_value       = 70
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
    predefined_metric_specification { predefined_metric_type = "ECSServiceAverageCPUUtilization" }
  }
}
