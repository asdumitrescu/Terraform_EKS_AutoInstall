# modules/iam/variables.tf

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "oidc_provider_arn" {
  type        = string
  description = "OIDC provider ARN"
}

variable "oidc_provider_url" {
  type        = string
  description = "OIDC provider URL"
}

variable "aws_lb_controller_policy_json" {
  type        = string
  description = "IAM policy document for the AWS Load Balancer Controller"
}

