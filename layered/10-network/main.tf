# Ultra-Low-Cost POC Environment - Complete Enterprise Reference Architecture
# Target: ~$30-35/day total infrastructure cost
#
# LAYER 10-network: VPC. Deployed on its own, with its own state per environment.

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

locals {
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

# VPC - Network Foundation
module "vpc" {
  source = "../../modules/vpc"

  environment = var.environment
  cluster_name = local.cluster_name 
  
  tags = local.common_tags
}
