variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "cluster_iam_role_name" {
  type        = string
  description = "Name of the IAM role for EKS cluster"
}

variable "cluster_security_group_name" {
  type        = string
  description = "Name of the security group for EKS cluster"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the cluster is deployed"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs"
}

variable "workstation_external_cidr" {
  type        = string
  description = "CIDR block of the workstation's external IP"
}

variable "oidc_thumbprint" {
  type        = string
  description = "OIDC provider thumbprint"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to resources"
  default     = {}
}

