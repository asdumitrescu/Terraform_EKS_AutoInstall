variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "vpc_name" {
  type        = string
  description = "Name tag for the VPC"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets"
}

variable "public_subnet_name" {
  type        = string
  description = "Name prefix for public subnets"
}

variable "azs" {
  type        = list(string)
  description = "List of availability zones"
}

variable "igw_name" {
  type        = string
  description = "Name tag for the Internet Gateway"
}

variable "public_route_table_name" {
  type        = string
  description = "Name tag for the public route table"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to resources"
  default     = {}
}
variable "private_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for private subnets"
}

variable "private_subnet_name" {
  type        = string
  description = "Name prefix for private subnets"
}

variable "create_nat_gateway" {
  type        = bool
  description = "Whether to create NAT Gateways for private subnets"
  default     = true
}

