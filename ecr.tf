
resource "aws_ecr_repository" "ecs_app" {
  name                 = "week13-ecs-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  lifecycle {
    prevent_destroy = false
  }

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
