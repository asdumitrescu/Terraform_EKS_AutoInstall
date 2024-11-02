variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "node_group_name" {
  type        = string
  description = "Name of the EKS node group"
}

variable "node_iam_role_name" {
  type        = string
  description = "Name of the IAM role for worker nodes"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs"
}

variable "desired_capacity" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 1
}

variable "max_capacity" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 1
}

variable "min_capacity" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 1
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to resources"
  default     = {}
}

