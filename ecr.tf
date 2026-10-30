resource "aws_ecr_repository" "ecs_app" {
  lifecycle { prevent_destroy = true }
  name                 = "week13-ecs-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name    = "week13-ecs-app"
    Project = "SIWES-Week13"
  }
}
