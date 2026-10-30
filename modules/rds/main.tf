
resource "aws_db_subnet_group" "this" {
  name       = "week13-rds-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name    = "week13-rds-subnet-group"
    Project = "SIWES-Week13"
  }
}

resource "aws_security_group" "rds" {
  name_prefix = "week13-rds-"
  description = "Security group for private MySQL database"
  vpc_id      = var.vpc_id

  tags = {
    Name    = "week13-rds-security-group"
    Project = "SIWES-Week13"
  }
}


resource "aws_vpc_security_group_ingress_rule" "mysql" {
  for_each = {
    for index, sg_id in var.allowed_security_group_ids :
    tostring(index) => sg_id
  }

  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = each.value

  ip_protocol = "tcp"
  from_port   = 3306
  to_port     = 3306

  description = "Allow MySQL from application security group"
}



resource "aws_db_instance" "this" {
  lifecycle { prevent_destroy = true }
  identifier = "week13-mysql-db"

  engine         = "mysql"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username

  manage_master_user_password = true

  db_subnet_group_name = aws_db_subnet_group.this.name

  vpc_security_group_ids = [
    aws_security_group.rds.id
  ]

  publicly_accessible = false
  multi_az            = var.multi_az

  # Disposable student lab settings
  backup_retention_period = 0
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = {
    Name    = "week13-mysql-db"
    Project = "SIWES-Week13"
  }
}
