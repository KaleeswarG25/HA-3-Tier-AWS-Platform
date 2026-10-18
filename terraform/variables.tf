
variable "aws_region" {
  description = "AWS region used to deploy the platform."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "Provide an AWS region in a valid region-name format."
  }
}

variable "project" {
  description = "Prefix used to identify project resources."
  type        = string
  default     = "ha-3tier"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.project))
    error_message = "Project must start with a lowercase letter and contain 3–20 lowercase letters, digits, or hyphens."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR range for the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Provide a valid IPv4 CIDR block for the VPC."
  }
}

variable "azs" {
  description = "Availability Zones used for public and private subnets."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]

  validation {
    condition     = length(var.azs) >= 2 && length(distinct(var.azs)) == length(var.azs)
    error_message = "Provide at least two distinct Availability Zones."
  }
}

variable "public_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

  validation {
    condition     = length(var.public_cidrs) >= 2 && length(distinct(var.public_cidrs)) == length(var.public_cidrs) && alltrue([for cidr in var.public_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Provide at least two distinct, valid public subnet CIDRs."
  }
}

variable "private_cidrs" {
  description = "CIDR blocks for private subnets."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

  validation {
    condition     = length(var.private_cidrs) >= 2 && length(distinct(var.private_cidrs)) == length(var.private_cidrs) && alltrue([for cidr in var.private_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Provide at least two distinct, valid private subnet CIDRs."
  }
}
