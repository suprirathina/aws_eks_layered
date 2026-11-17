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

# VPC Endpoints Configuration
variable "vpc_endpoints_enable_ecr" {
  description = "Enable ECR VPC endpoints for private image pulls"
  type        = bool
  default     = true  # Enable for private container registry access
}

variable "vpc_endpoints_enable_s3" {
  description = "Enable S3 VPC endpoint (Gateway type - no additional cost)"
  type        = bool
  default     = true  # Enable for ECR layer storage access
}

variable "vpc_endpoints_enable_secrets" {
  description = "Enable Secrets Manager VPC endpoint"
  type        = bool
  default     = true  # Enable for secure credential access
}

variable "vpc_endpoints_enable_logs" {
  description = "Enable CloudWatch Logs VPC endpoint"
  type        = bool
  default     = true  # Enable for application logging
}

variable "vpc_endpoints_enable_monitoring" {
  description = "Enable CloudWatch Monitoring VPC endpoint"
  type        = bool
  default     = true  # Enable for metrics collection
}

variable "vpc_endpoints_enable_sts" {
  description = "Enable STS VPC endpoint for IAM role assumptions"
  type        = bool
  default     = true  # Enable for OIDC/IAM integration
}

variable "vpc_endpoints_enable_eks" {
  description = "Enable EKS VPC endpoint for private cluster access"
  type        = bool
  default     = false  # Optional - can use public endpoint for POC
}

variable "vpc_endpoints_enable_autoscaling" {
  description = "Enable Auto Scaling VPC endpoint for cluster autoscaler"
  type        = bool
  default     = false  # Optional - disable for cost savings
}

variable "vpc_endpoints_enable_logging" {
  description = "Enable VPC endpoint access logging"
  type        = bool
  default     = false  # Disabled for cost optimization
}

variable "vpc_endpoints_enable_dns_resolver" {
  description = "Enable custom DNS resolver for VPC endpoints"
  type        = bool
  default     = false  # Disabled for cost optimization - use built-in DNS
}
