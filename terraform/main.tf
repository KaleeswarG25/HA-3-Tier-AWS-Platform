terraform {
  required_version = ">= 1.5"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "aws" { region = var.aws_region }

module "vpc" {
  source        = "./modules/vpc"
  project       = var.project
  azs           = var.azs
  public_cidrs  = var.public_cidrs
  private_cidrs = var.private_cidrs
}

module "security_groups" {
  source   = "./modules/security-groups"
  project  = var.project
  vpc_id   = module.vpc.vpc_id
  vpc_cidr = var.vpc_cidr
}

module "alb" {
  source         = "./modules/alb"
  project        = var.project
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnets
  alb_sg_id      = module.security_groups.alb_sg_id
}

module "asg" {
  source           = "./modules/asg"
  project          = var.project
  private_subnets  = module.vpc.private_subnets
  target_group_arn = module.alb.target_group_arn
  app_sg_id        = module.security_groups.app_sg_id
  userdata_path    = "${path.module}/../app/userdata.sh"
}

module "rds" {
  source          = "./modules/rds"
  project         = var.project
  private_subnets = module.vpc.private_subnets
  rds_sg_id       = module.security_groups.rds_sg_id
}