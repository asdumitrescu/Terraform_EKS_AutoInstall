variable "aws_region" {
  default = "us-east-1"
}

variable "cluster_name" {
  default = "terraform-eks-demo"
  type    = string
}

variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  description = "CIDR block for the VPC"
}

variable "public_subnet_cidrs" {
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
  description = "List of CIDR blocks for public subnets"
}

variable "private_subnet_cidrs" {
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
  description = "List of CIDR blocks for private subnets"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {
    "Environment" = "dev"
    "Project"     = "terraform-eks-demo"
  }
}

variable "desired_capacity" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 2
}

variable "max_capacity" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 3
}

variable "min_capacity" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 1
}

