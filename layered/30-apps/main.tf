# Ultra-Low-Cost POC Environment - Complete Enterprise Reference Architecture
# Target: ~$30-35/day total infrastructure cost
#
# LAYER 30-apps: bastion, load balancer, container registry and secrets.
# Needs layers 10-network and 20-cluster to be applied first.

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

# Outputs of the layers below (10-network and 20-cluster), read from their state
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "${var.environment}/10-network/terraform.tfstate"
    region = var.state_region
  }
}

data "terraform_remote_state" "cluster" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "${var.environment}/20-cluster/terraform.tfstate"
    region = var.state_region
  }
}

locals {
  network = data.terraform_remote_state.network.outputs
  cluster = data.terraform_remote_state.cluster.outputs

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

# Bastion Host - Secure access to private resources
module "bastion" {
  source = "../../modules/bastion"

  project_name = var.project_name
  environment  = var.environment
  region       = var.region

  # Network Configuration
  vpc_id    = local.network.vpc_id
  subnet_id = local.network.public_subnet_ids[0]  # First public subnet

  # EKS Integration
  cluster_name = local.cluster.cluster_name
  cluster_arn  = local.cluster.cluster_arn

  # Security Configuration
  allowed_cidr_blocks = var.bastion_allowed_cidrs
  ec2_key_pair_name  = var.ec2_key_pair_name

  # Cost Optimization
  instance_type        = "t3.nano"  # $3.50/day
  use_elastic_ip      = false       # Save ~$3.65/month
  auto_shutdown       = true        # Enable auto-shutdown

  common_tags = local.common_tags
}

# Application Load Balancer - Enterprise ingress pattern
module "alb" {
  source = "../../modules/alb"

  project_name = var.project_name
  environment  = var.environment

  # Network Configuration
  vpc_id            = local.network.vpc_id
  public_subnet_ids = local.network.public_subnet_ids

  # ALB Configuration
  internal                   = false  # Internet-facing
  enable_deletion_protection = false  # Allow easy teardown for POC
  enable_access_logs        = false   # Cost optimization - disabled by default
  
  # CloudWatch Integration - disabled by default for cost control
  enable_cloudwatch_integration = false  # Enable for production monitoring
  # cloudwatch_log_group_name    = "/aws/alb/${var.project_name}/micro"  # Uncomment to enable

  # Target Groups for micro services
  target_groups = {
    default = {
      port        = 80
      protocol    = "HTTP"
      target_type = "ip"
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        interval            = 30
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }
      stickiness = null
    }
    backend = {
      port        = 8080
      protocol    = "HTTP"
      target_type = "ip"
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        interval            = 30
        matcher             = "200,404"
        path                = "/health"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 3
      }
      stickiness = null
    }
  }

  # Listener Rules
  listener_rules = {
    default_app = {
      priority = 100
      action = {
        type             = "forward"
        target_group_key = "default"
      }
      conditions = [
        {
          type   = "path-pattern"
          values = ["/", "/app", "/app/*"]
        }
      ]
    }
    backend_api = {
      priority = 200
      action = {
        type             = "forward"
        target_group_key = "backend"
      }
      conditions = [
        {
          type   = "path-pattern"
          values = ["/api", "/api/*"]
        }
      ]
    }
  }

  common_tags = local.common_tags
}

# ECR - Container Registry
module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment

  # Repository Configuration
  repositories = {
    frontend = {
      image_tag_mutability = "MUTABLE"
      scan_on_push         = true
      encryption_type      = "AES256"
      force_delete        = true  # Allow easy cleanup for POC
      application         = "frontend"
      lifecycle_policy = {
        rules = [
          {
            rulePriority = 1
            description  = "Keep last 5 production images"
            selection = {
              tagStatus     = "tagged"
              tagPrefixList = ["prod", "production", "release"]
              countType     = "imageCountMoreThan"
              countNumber   = 5
            }
            action = {
              type = "expire"
            }
          },
          {
            rulePriority = 2
            description  = "Delete untagged images after 1 day"
            selection = {
              tagStatus   = "untagged"
              countType   = "sinceImagePushed"
              countUnit   = "days"
              countNumber = 1
            }
            action = {
              type = "expire"
            }
          }
        ]
      }
    }
    backend = {
      image_tag_mutability = "MUTABLE"
      scan_on_push         = true
      encryption_type      = "AES256"
      force_delete        = true
      application         = "backend"
      lifecycle_policy = {
        rules = [
          {
            rulePriority = 1
            description  = "Keep last 5 production images"
            selection = {
              tagStatus     = "tagged"
              tagPrefixList = ["prod", "production", "release"]
              countType     = "imageCountMoreThan"
              countNumber   = 5
            }
            action = {
              type = "expire"
            }
          },
          {
            rulePriority = 2
            description  = "Delete untagged images after 1 day"
            selection = {
              tagStatus   = "untagged"
              countType   = "sinceImagePushed"
              countUnit   = "days"
              countNumber = 1
            }
            action = {
              type = "expire"
            }
          }
        ]
      }
    }
  }

  # Cost Optimization
  enable_pull_through_cache = false
  enable_scan_logging      = false
  create_kms_key          = false

  common_tags = local.common_tags
}

# Secrets Management - Enterprise credential security
module "secrets" {
  source = "../../modules/secrets"

  project_name = var.project_name
  environment  = var.environment
  region       = var.region

  # External Secrets Operator Integration
  enable_external_secrets_operator = true
  eks_oidc_provider_arn           = local.cluster.oidc_provider_arn

  # Default secrets for micro environment
  secrets = {
    database = {
      description             = "Database connection credentials for micro POC"
      recovery_window_in_days = 0  # Immediate deletion for POC
      application            = "backend"
      secret_type           = "database"
      static_values = {
        username = "secure_app_user"
        host     = "localhost"
        port     = "5432"
        database = "secure_app_db"
        engine   = "postgresql"
      }
      password_references = {
        password = "db_password"
      }
    }
    api_keys = {
      description             = "External API keys and service credentials"
      recovery_window_in_days = 0
      application            = "frontend"
      secret_type           = "api-keys"
      static_values = {
        redis_connection = "redis://localhost:6379"
      }
      password_references = {
        auth0_client_secret = "auth0_secret"
      }
      id_references = {
        stripe_api_key  = "api_suffix"
        auth0_client_id = "api_suffix"
        sendgrid_api_key = "api_suffix"
      }
    }
    jwt = {
      description             = "JWT signing and verification keys"
      recovery_window_in_days = 0
      application            = "backend"
      secret_type           = "jwt"
      static_values = {
        jwt_issuer       = "secure-app-micro"
        jwt_expiry_hours = "24"
        jwt_refresh_days = "30"
      }
      password_references = {
        jwt_secret_key  = "jwt_secret"
        jwt_refresh_key = "jwt_refresh"
      }
    }
  }

  # Cost Optimization
  create_kms_key       = false
  enable_access_logging = false
  create_k8s_examples  = true

  common_tags = local.common_tags
}
