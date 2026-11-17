# Ultra-Low-Cost POC Environment - Complete Enterprise Reference Architecture
# Target: ~$30-35/day total infrastructure cost
#
# LAYER 20-cluster: IAM and the EKS cluster. Needs layer 10-network to be applied first.

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  # State location is supplied at init time (see envs/<env>.backend.hcl and README.md)
  backend "s3" {}
}

provider "aws" {
  region = var.region
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Outputs of the layer below (10-network), read from its state
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "${var.environment}/10-network/terraform.tfstate"
    region = var.state_region
  }
}

locals {
  network = data.terraform_remote_state.network.outputs

  cluster_name = "${var.project_name}-${var.environment}-eks"
  
  common_tags = {
    Project       = var.project_name
    CostCenter    = "poc"
    ManagedBy     = "terraform"
    Owner         = "devops-team"
  }
}

#####################################
# CORE INFRASTRUCTURE MODULES
#####################################

# IAM - Identity and Access Management
module "iam" {
  source = "../../modules/iam"

  environment                     = var.environment
  identity_center_instance_arn    = var.identity_center_instance_arn
  permission_sets                 = var.permission_sets
  
  # Enable enterprise defaults
  enable_default_permission_sets = var.enable_default_permission_sets
  enable_default_eks_roles       = var.enable_default_eks_roles
  eks_oidc_provider_arn          = module.eks.oidc_provider_arn
  
  # Optional: Override specific roles if needed
  eks_roles = {
    # Add any environment-specific role overrides here
  }
  
  tags = local.common_tags
  
  depends_on = [module.eks]
}

# EKS - Kubernetes Cluster
module "eks" {
  source = "../../modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = "1.31"
  
  vpc_id     = local.network.vpc_id
  subnet_ids = local.network.private_subnet_ids
  
  environment = var.environment
  tags        = local.common_tags
}
