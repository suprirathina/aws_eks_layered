# Ultra-Low-Cost POC Environment - Complete Enterprise Reference Architecture
# Target: ~$30-35/day total infrastructure cost
#
# LAYER 15-vpc-endpoints: private AWS service access. Kept as its own layer because the
# Interface endpoints are the main cost item: deploy it only when you want them.
# Needs layer 10-network to be applied first.

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

  common_tags = {
    Project       = var.project_name
    CostCenter    = "poc"
    ManagedBy     = "terraform"
    Owner         = "devops-team"
  }
}

#####################################
# ENTERPRISE REFERENCE ARCHITECTURE MODULES
#####################################

# VPC Endpoints - Private AWS service access (replaces NAT Gateway)
module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints"

  project_name = var.project_name
  environment  = var.environment
  region       = var.region

  # Network Configuration
  vpc_id             = local.network.vpc_id
  private_subnet_ids = local.network.private_subnet_ids
  route_table_ids    = local.network.private_route_table_ids
  
  # Security Configuration
  allowed_cidr_blocks = [local.network.vpc_cidr_block]

  # VPC Endpoints for cost-effective private access
  vpc_endpoints = {
    s3 = {
      service_name        = "com.amazonaws.${var.region}.s3"
      endpoint_type      = "Gateway"
      private_dns_enabled = false
      policy = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = "*"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:DeleteObject",
              "s3:ListBucket"
            ]
            Resource = [
              "arn:aws:s3:::${var.project_name}-*",
              "arn:aws:s3:::${var.project_name}-*/*",
              "arn:aws:s3:::prod-${var.region}-starport-layer-bucket",
              "arn:aws:s3:::prod-${var.region}-starport-layer-bucket/*"
            ]
          }
        ]
      }
    }
    ecr_api = {
      service_name        = "com.amazonaws.${var.region}.ecr.api"
      endpoint_type      = "Interface"
      private_dns_enabled = true
      policy = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = "*"
            Action = [
              "ecr:GetAuthorizationToken",
              "ecr:BatchCheckLayerAvailability",
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage",
              "ecr:DescribeRepositories",
              "ecr:DescribeImages"
            ]
            Resource = "*"
          }
        ]
      }
    }
    ecr_dkr = {
      service_name        = "com.amazonaws.${var.region}.ecr.dkr"
      endpoint_type      = "Interface"
      private_dns_enabled = true
      policy = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = "*"
            Action = [
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage",
              "ecr:BatchCheckLayerAvailability"
            ]
            Resource = "*"
          }
        ]
      }
    }
    secretsmanager = {
      service_name        = "com.amazonaws.${var.region}.secretsmanager"
      endpoint_type      = "Interface"
      private_dns_enabled = true
      policy = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = "*"
            Action = [
              "secretsmanager:GetSecretValue",
              "secretsmanager:DescribeSecret"
            ]
            Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-*"
          }
        ]
      }
    }
    logs = {
      service_name        = "com.amazonaws.${var.region}.logs"
      endpoint_type      = "Interface"
      private_dns_enabled = true
      policy = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = "*"
            Action = [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents",
              "logs:DescribeLogGroups",
              "logs:DescribeLogStreams"
            ]
            Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        ]
      }
    }
    monitoring = {
      service_name        = "com.amazonaws.${var.region}.monitoring"
      endpoint_type      = "Interface"
      private_dns_enabled = true
      policy = null
    }
    sts = {
      service_name        = "com.amazonaws.${var.region}.sts"
      endpoint_type      = "Interface"
      private_dns_enabled = true
      policy = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = "*"
            Action = [
              "sts:AssumeRole",
              "sts:AssumeRoleWithWebIdentity",
              "sts:GetCallerIdentity"
            ]
            Resource = "*"
          }
        ]
      }
    }
  }

  # Cost Optimization
  enable_flow_logs    = false
  enable_dns_resolver = false

  common_tags = local.common_tags
}
