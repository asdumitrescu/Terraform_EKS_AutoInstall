# Get availability zones
data "aws_availability_zones" "available" {}

# Get workstation external IP
data "http" "workstation_external_ip" {
  url = "http://ipv4.icanhazip.com"
}
data "http" "aws_lb_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, length(var.public_subnet_cidrs))
}

locals {
  workstation_external_cidr = "${chomp(data.http.workstation_external_ip.response_body)}/32"
  oidc_thumbprint           = "9e99a48a9960b14926bb7f3b02e22da2b0ab7280" # For us-east-1
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr                = var.vpc_cidr
  vpc_name                = "${var.cluster_name}-vpc"
  public_subnet_cidrs     = var.public_subnet_cidrs
  public_subnet_name      = "${var.cluster_name}-public-subnet"
  private_subnet_cidrs    = var.private_subnet_cidrs
  private_subnet_name     = "${var.cluster_name}-private-subnet"
  azs                     = local.azs
  igw_name                = "${var.cluster_name}-igw"
  public_route_table_name = "${var.cluster_name}-public-rt"
  tags                    = var.tags
}



# EKS Cluster Module
module "eks_cluster" {
  source = "./modules/eks_cluster"

  cluster_name                = var.cluster_name
  cluster_iam_role_name       = "${var.cluster_name}-cluster-role"
  cluster_security_group_name = "${var.cluster_name}-cluster-sg"
  vpc_id                      = module.vpc.vpc_id
  private_subnet_ids          = module.vpc.private_subnet_ids
  workstation_external_cidr   = local.workstation_external_cidr
  oidc_thumbprint             = local.oidc_thumbprint
  tags                        = var.tags
}

# EKS Node Group Module
module "eks_node_group" {
  source = "./modules/eks_node_group"

  cluster_name       = module.eks_cluster.cluster_name
  node_group_name    = "${var.cluster_name}-node-group"
  node_iam_role_name = "${var.cluster_name}-node-role"
  private_subnet_ids = module.vpc.private_subnet_ids
  desired_capacity   = 1
  max_capacity       = 1
  min_capacity       = 1
  tags               = var.tags
}

module "iam" {
  source = "./modules/iam"

  cluster_name                   = var.cluster_name
  oidc_provider_arn              = module.eks_cluster.oidc_provider_arn
  oidc_provider_url              = module.eks_cluster.oidc_provider_url
  aws_lb_controller_policy_json  = data.http.aws_lb_controller_policy.response_body
}



