# ==============================================================
# Jerney EKS Cluster - EKS Auto Mode
# Region: us-west-2 (Oregon)
# Kubernetes: 1.35
# ==============================================================

# --------------------------------------------------------------
# Availability Zones
# --------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

# --------------------------------------------------------------
# VPC
# --------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs = local.azs

  # Private subnets
  private_subnets = [
    for k, v in local.azs :
    cidrsubnet(var.vpc_cidr, 4, k)
  ]

  # Public subnets
  public_subnets = [
    for k, v in local.azs :
    cidrsubnet(var.vpc_cidr, 8, k + 48)
  ]

  # NAT Gateway
  enable_nat_gateway = true
  single_nat_gateway = true

  # Required for EKS load balancers
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# --------------------------------------------------------------
# EKS Cluster - Auto Mode
# --------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # ------------------------------------------------------------
  # EKS Auto Mode
  # ------------------------------------------------------------

  cluster_compute_config = {
    enabled = true

    node_pools = [
      "general-purpose",
      "system"
    ]
  }

  # ------------------------------------------------------------
  # Networking
  # ------------------------------------------------------------

  vpc_id = module.vpc.vpc_id

  subnet_ids = module.vpc.private_subnets

  # ------------------------------------------------------------
  # EKS API Endpoint
  # ------------------------------------------------------------

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # ------------------------------------------------------------
  # Authentication
  # ------------------------------------------------------------

  authentication_mode = "API"

  # Give the IAM identity running Terraform
  # administrator access to the cluster
  enable_cluster_creator_admin_permissions = true

  # ------------------------------------------------------------
  # Secrets Encryption
  # ------------------------------------------------------------

  cluster_encryption_config = {
    resources = [
      "secrets"
    ]
  }

  # ------------------------------------------------------------
  # Control Plane Logging
  # ------------------------------------------------------------

  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  # ------------------------------------------------------------
  # Tags
  # ------------------------------------------------------------

  tags = {
    Project     = "Jerney"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Kubernetes  = var.cluster_version
    AutoMode    = "enabled"
  }
}
