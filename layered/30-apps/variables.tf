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

# Bastion Host Configuration
variable "ec2_key_pair_name" {
  description = "Name of EC2 Key Pair for bastion host SSH access"
  type        = string
  default     = null  # You'll need to create a key pair in AWS console
}

variable "bastion_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH to bastion host"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict to your IP in production
}

variable "bastion_use_eip" {
  description = "Whether to assign Elastic IP to bastion host"
  type        = bool
  default     = false  # Save costs - use dynamic IP
}
# Application Load Balancer Configuration
variable "alb_enable_access_logs" {
  description = "Enable ALB access logs to S3 (additional cost)"
  type        = bool
  default     = false  # Disabled for cost optimization
}

variable "alb_enable_ssl" {
  description = "Enable HTTPS listener with SSL certificate"
  type        = bool
  default     = false  # Disabled for POC - HTTP only
}

variable "ssl_certificate_arn" {
  description = "ARN of SSL certificate for HTTPS listener"
  type        = string
  default     = null
}
# Elastic Container Registry Configuration
variable "ecr_enable_image_scanning" {
  description = "Enable vulnerability scanning on image push"
  type        = bool
  default     = true  # Enable for security best practices
}

variable "ecr_enable_cross_account_access" {
  description = "Enable cross-account access to ECR repositories"
  type        = bool
  default     = false  # Disabled for single-account POC
}

variable "ecr_cross_account_principals" {
  description = "List of AWS account ARNs for cross-account ECR access"
  type        = list(string)
  default     = []
}

variable "ecr_enable_pull_through_cache" {
  description = "Enable ECR pull-through cache for upstream registries"
  type        = bool
  default     = false  # Disabled for cost optimization
}
# Secrets Management Configuration
variable "secrets_enable_rotation" {
  description = "Enable automatic secret rotation"
  type        = bool
  default     = false  # Disabled for POC to reduce complexity
}

variable "secrets_enable_kms" {
  description = "Enable additional KMS encryption for secrets"
  type        = bool
  default     = false  # Disabled for cost optimization - Secrets Manager has built-in encryption
}

variable "secrets_enable_tls" {
  description = "Create TLS certificate secrets for internal services"
  type        = bool
  default     = false  # Disabled for POC unless needed
}

variable "secrets_enable_logging" {
  description = "Enable CloudWatch logging for secrets access"
  type        = bool
  default     = false  # Disabled for cost optimization
}

variable "secrets_deploy_external_secrets" {
  description = "Create configuration for External Secrets Operator deployment"
  type        = bool
  default     = true  # Enable for K8s integration
}

variable "secrets_create_k8s_examples" {
  description = "Create Kubernetes secret examples file"
  type        = bool
  default     = true  # Create examples for reference
}
