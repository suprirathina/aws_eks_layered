# Ultra-Low-Cost POC Variables - Simplified

variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "secure-app"
}

# Added for the layered layout: one code copy, many environments
variable "environment" {
  description = "Environment name (micro, dev, staging, prod). Set in envs/<env>.tfvars"
  type        = string
}

# Added for the layered layout: where the other layers keep their state
variable "state_bucket" {
  description = "S3 bucket that holds the Terraform state of all layers. Set in envs/<env>.tfvars"
  type        = string
}

variable "state_region" {
  description = "Region of the state bucket. Set in envs/<env>.tfvars"
  type        = string
}

# Enhanced Observability Configuration
variable "monitoring_enable_sns" {
  description = "Enable SNS notifications for CloudWatch alarms"
  type        = bool
  default     = false  # Disabled for cost optimization - enable if you want email alerts
}

variable "monitoring_log_retention_days" {
  description = "Number of days to retain monitoring logs"
  type        = number
  default     = 3  # Cost optimized - minimum retention for troubleshooting
}

variable "monitoring_enable_detailed_metrics" {
  description = "Enable detailed CloudWatch metrics (additional cost)"
  type        = bool
  default     = false  # Disabled for cost optimization
}
