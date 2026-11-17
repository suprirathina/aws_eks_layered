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
