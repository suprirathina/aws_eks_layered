# Ultra-Low-Cost POC Environment - Complete Enterprise Reference Architecture
# Target: ~$30-35/day total infrastructure cost
#
# LAYER 00-baseline: account-level security and cost monitoring. Deployed once per account/environment.

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

# Security - Security configurations and policies
module "security" {
  source = "../../modules/security"

  environment = var.environment
  tags        = local.common_tags
}

#####################################
# COST MONITORING
#####################################
resource "aws_budgets_budget" "micro_poc_budget" {
  name         = "${var.environment}-poc-daily-budget"
  budget_type  = "COST"
  limit_amount = var.daily_cost_limit
  limit_unit   = "USD"
  time_unit    = "DAILY"

  time_period_start = formatdate("YYYY-MM-DD_HH:mm", timestamp())

  cost_filters = {
    Tag = {
      "Project"     = [var.project_name]
      "Environment" = [var.environment]
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = var.cost_alert_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN" 
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.cost_alert_emails
  }

  tags = local.common_tags
}
