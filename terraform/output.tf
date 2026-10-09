
output "vpc_id" { value = module.vpc.vpc_id }
output "db_endpoint" { value = module.rds.db_endpoint }
output "db_password" {
  value     = module.rds.db_password
  sensitive = true
}

output "asg_name" { value = module.asg.asg_name }

output "alb_url" {
  value = "http://${module.alb.alb_dns_name}"
}

