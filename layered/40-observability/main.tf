# Ultra-Low-Cost POC Environment - Complete Enterprise Reference Architecture
# Target: ~$30-35/day total infrastructure cost
#
# LAYER 40-observability: monitoring. Needs layers 20-cluster and 30-apps to be applied first.

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

# Outputs of the layers below (20-cluster and 30-apps), read from their state
data "terraform_remote_state" "cluster" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "${var.environment}/20-cluster/terraform.tfstate"
    region = var.state_region
  }
}

data "terraform_remote_state" "apps" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "${var.environment}/30-apps/terraform.tfstate"
    region = var.state_region
  }
}

locals {
  cluster = data.terraform_remote_state.cluster.outputs
  apps    = data.terraform_remote_state.apps.outputs

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

# Enhanced Observability - Enterprise monitoring
module "observability" {
  source = "../../modules/observability"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = local.cluster.cluster_name

  # Container Insights for EKS
  enable_container_insights = true
  container_insights_log_groups = {
    cluster = {
      retention_days = 3
      kms_key_id    = null
    }
    host = {
      retention_days = 3
      kms_key_id    = null
    }
    dataplane = {
      retention_days = 3
      kms_key_id    = null
    }
  }

  # CloudWatch Dashboards
  dashboards = {
    eks_overview = {
      body = {
        widgets = [
          {
            type   = "metric"
            x      = 0
            y      = 0
            width  = 12
            height = 6
            properties = {
              metrics = [
                ["AWS/EKS", "cluster_failed_request_count", "ClusterName", local.cluster.cluster_name],
                [".", "cluster_node_count", ".", "."],
                [".", "cluster_number_of_running_pods", ".", "."]
              ]
              view    = "timeSeries"
              stacked = false
              region  = var.region
              title   = "EKS Cluster Overview"
              period  = 300
            }
          }
        ]
      }
    }
    app_performance = {
      body = {
        widgets = [
          {
            type   = "metric"
            x      = 0
            y      = 0
            width  = 12
            height = 6
            properties = {
              metrics = [
                ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.apps.load_balancer_arn],
                [".", "RequestCount", ".", "."]
              ]
              view    = "timeSeries"
              stacked = false
              region  = var.region
              title   = "Application Performance"
              period  = 300
            }
          }
        ]
      }
    }
  }

  # Critical Alarms
  metric_alarms = {
    high_pod_cpu = {
      description         = "High pod CPU utilization"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = "2"
      metric_name        = "pod_cpu_utilization"
      namespace          = "AWS/ContainerInsights"
      period             = "300"
      statistic          = "Average"
      threshold          = "80"
      dimensions = {
        ClusterName = local.cluster.cluster_name
      }
      severity = "medium"
    }
    alb_response_time = {
      description         = "High ALB response time"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = "2"
      metric_name        = "TargetResponseTime"
      namespace          = "AWS/ApplicationELB"
      period             = "300"
      statistic          = "Average"
      threshold          = "2"
      dimensions = {
        LoadBalancer = local.apps.load_balancer_arn
      }
      severity = "high"
    }
  }

  # Cost Optimization
  cost_optimization = {
    log_retention_days        = 3
    enable_detailed_monitoring = false
    metric_filter_sampling    = 1.0
  }

  common_tags = local.common_tags
}
