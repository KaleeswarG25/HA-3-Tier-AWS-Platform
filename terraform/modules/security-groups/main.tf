variable "project" { type = string }
variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }
variable "alb_sg_id" { default = "" } # set below instead

# ALB SG — internet → ALB:80
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "ALB - allow HTTP from internet"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-alb-sg" }
}

# App SG — ALB → EC2:80, and SSH from VPC (via SSM instead if you prefer)
resource "aws_security_group" "app" {
  name        = "${var.project}-app-sg"
  description = "App EC2 - allow HTTP from ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-app-sg" }
}

# RDS SG — app → RDS:3306
resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "RDS - allow MySQL from app"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-rds-sg" }
}

output "alb_sg_id" { value = aws_security_group.alb.id }
output "app_sg_id" { value = aws_security_group.app.id }
output "rds_sg_id" { value = aws_security_group.rds.id }