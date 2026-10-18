variable "project" { type = string }
variable "vpc_cidr" { default = "10.0.0.0/16" }

variable "azs" {
  description = "Availability Zones used by the VPC subnets."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2 && length(distinct(var.azs)) == length(var.azs)
    error_message = "Provide at least two distinct Availability Zones."
  }
}

variable "publi_cidrs" {
  
  description = "CIDR blocks for public subnets, one per Availability Zone."
  type        = list(string)

  validation {
    condition     = length(var.public_cidrs) == length(var.azs)
    error_message = "The number of public subnet CIDRs must match the number of Availability Zones."
  }

  validation {
    condition     = alltrue([for cidr in var.public_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Every public subnet CIDR must be valid."
  }
}

variable "private_cidrs" {
  description = "CIDR blocks for private subnets, one per Availability Zone."
  type        = list(string)

  validation {
    condition     = length(var.private_cidrs) == length(var.azs)
    error_message = "The number of private subnet CIDRs must match the number of Availability Zones."
  }

  validation {
    condition     = alltrue([for cidr in var.private_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Every private subnet CIDR must be valid."
  }
}


resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${var.project}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.project}-igw" }
}

# ---- Public subnets (ALB) ----
resource "aws_subnet" "public" {
  count                   = length(var.public_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project}-public-${var.azs[count.index]}"
    Tier = "public"
  }
}

# ---- Private subnets (app + db) ----
resource "aws_subnet" "private" {
  count             = length(var.private_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags = {
    Name = "${var.project}-private-${var.azs[count.index]}"
    Tier = "private"
  }
}

# ---- NAT gateway (single, cost-optimized) ----
resource "aws_eip" "nat" { domain = "vpc" }

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.project}-nat" }
  depends_on    = [aws_internet_gateway.this]
}

# ---- Route tables ----
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${var.project}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = { Name = "${var.project}-private-rt" }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ---- Outputs ----
output "vpc_id" { value = aws_vpc.this.id }
output "public_subnets" { value = aws_subnet.public[*].id }
output "private_subnets" { value = aws_subnet.private[*].id }
output "azs" { value = var.azs }