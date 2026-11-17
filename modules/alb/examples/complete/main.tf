#####################################
# COMPLETE ALB EXAMPLE WITH CLOUDWATCH INTEGRATION
#####################################

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Local variables
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Module      = "alb-example"
    ManagedBy   = "terraform"
  }
}

# VPC Module (simplified for example)
module "vpc" {
  source = "../../../vpc"
  
  project_name = var.project_name
  environment  = var.environment
  
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  
  common_tags = local.common_tags
}

#####################################
# ALB MODULE - COMPLETE CONFIGURATION
#####################################

module "alb" {
  source = "../.."
  
  project_name = var.project_name
  environment  = var.environment
  
  # Network Configuration
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  
  # ALB Configuration
  internal     = false
  enable_http  = true
  enable_https = true
  
  # SSL Configuration
  ssl_certificate_arn = var.ssl_certificate_arn
  ssl_policy         = "ELBSecurityPolicy-TLS-1-2-2017-01"
  
  # Target Groups
  target_groups = {
    web = {
      port                 = 80
      protocol            = "HTTP"
      target_type         = "instance"
      health_check_path   = "/health"
      health_check_matcher = "200"
      health_check_interval = 30
      health_check_timeout  = 5
      healthy_threshold     = 2
      unhealthy_threshold   = 3
    }
    api = {
      port                 = 8080
      protocol            = "HTTP"
      target_type         = "instance"
      health_check_path   = "/api/health"
      health_check_matcher = "200,201"
      health_check_interval = 15
      health_check_timeout  = 10
      healthy_threshold     = 2
      unhealthy_threshold   = 5
    }
  }
  
  # Routing Rules
  listener_rules = {
    web_default = {
      priority = 100
      action = {
        type             = "forward"
        target_group_key = "web"
      }
      conditions = [
        {
          type   = "path-pattern"
          values = ["/*"]
        }
      ]
    }
    api_routing = {
      priority = 200
      action = {
        type             = "forward"
        target_group_key = "api"
      }
      conditions = [
        {
          type   = "path-pattern"
          values = ["/api/*"]
        }
      ]
    }
  }
  
  # Security Group Rules
  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP access from internet"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS access from internet"
    }
  ]
  
  # Access Logs Configuration
  enable_access_logs         = true
  access_logs_retention_days = 7  # Short retention for cost optimization
  
  # CloudWatch Integration (Full Monitoring)
  enable_cloudwatch_integration = true
  cloudwatch_log_group_name    = "/aws/alb/${var.project_name}/${var.environment}"
  
  # Advanced Lambda Configuration
  enable_lambda_tracing       = true   # Enable X-Ray tracing
  enable_scheduled_processing = false  # Disable scheduled processing for cost
  lambda_memory_size         = 256     # Increase memory for better performance
  lambda_timeout             = 300     # 5 minutes timeout
  
  common_tags = local.common_tags
}

#####################################
# CLOUDWATCH DASHBOARDS & ALARMS
#####################################

# CloudWatch Dashboard for ALB Metrics
resource "aws_cloudwatch_dashboard" "alb_monitoring" {
  dashboard_name = "${var.project_name}-${var.environment}-alb"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["ALB/ProcessedMetrics", "TotalRequests", "Project", var.project_name, "Environment", var.environment],
            [".", "Throughput", ".", ".", ".", "."],
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", module.alb.load_balancer_arn]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "ALB Request Volume"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["ALB/ProcessedMetrics", "AverageResponseTime", "Project", var.project_name, "Environment", var.environment],
            [".", "P95ResponseTime", ".", ".", ".", "."],
            [".", "MaxResponseTime", ".", ".", ".", "."],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", module.alb.load_balancer_arn]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "ALB Response Times"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["ALB/ProcessedMetrics", "Status2xxPercent", "Project", var.project_name, "Environment", var.environment],
            [".", "Status4xxPercent", ".", ".", ".", "."],
            [".", "Status5xxPercent", ".", ".", ".", "."],
            [".", "ErrorRate", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "ALB Status Code Distribution"
          period  = 300
        }
      }
    ]
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "alb_high_error_rate" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ErrorRate"
  namespace           = "ALB/ProcessedMetrics"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"  # 5% error rate
  alarm_description   = "This metric monitors ALB error rate"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    Project     = var.project_name
    Environment = var.environment
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "alb_high_response_time" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "P95ResponseTime"
  namespace           = "ALB/ProcessedMetrics"
  period              = "300"
  statistic           = "Average"
  threshold           = "2"  # 2 seconds
  alarm_description   = "This metric monitors ALB P95 response time"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    Project     = var.project_name
    Environment = var.environment
  }
  
  tags = local.common_tags
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alb-alerts"
  
  tags = local.common_tags
}