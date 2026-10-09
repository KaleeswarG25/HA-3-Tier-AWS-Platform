variable "aws_region" { default = "us-east-1" }
variable "project" { default = "ha-3tier" }
variable "vpc_cidr" { default = "10.0.0.0/16" }

variable "azs" {
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
variable "public_cidrs" {
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}
variable "private_cidrs" {
  default = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}