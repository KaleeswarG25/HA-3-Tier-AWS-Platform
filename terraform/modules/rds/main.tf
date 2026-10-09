variable "project"            { type = string }
variable "private_subnets"    { type = list(string) }
variable "rds_sg_id"          { type = string }
variable "db_name"            { default = "appdb" }
variable "db_username"        { default = "admin" }
variable "instance_class"     { default = "db.t3.micro" }

resource "random_password" "db" {
  length  = 20
  special = false
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = var.private_subnets
  tags       = { Name = "${var.project}-db-subnet-group" }
}

resource "aws_db_instance" "this" {
  identifier             = "${var.project}-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.instance_class
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp3"
  storage_encrypted      = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 3306

  multi_az               = true # ← THE HIGH AVAILABILITY
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]

  backup_retention_period   = 7
  backup_window             = "03:00-04:00"
  maintenance_window        = "sun:04:00-sun:05:00"
  skip_final_snapshot       = true
  deletion_protection       = false

  performance_insights_enabled = true

  tags = { Name = "${var.project}-db" }
}

output "db_endpoint" { value = aws_db_instance.this.endpoint }
output "db_name"     { value = aws_db_instance.this.db_name }
output "db_username" { value = aws_db_instance.this.username }
output "db_password" {
  value     = random_password.db.result
  sensitive = true
}