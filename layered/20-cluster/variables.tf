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

#####################################
# IAM MODULE CONFIGURATION
#####################################

variable "enable_default_permission_sets" {
  description = "Enable default permission sets for common access patterns"
  type        = bool
  default     = true
}

variable "enable_default_eks_roles" {
  description = "Enable default EKS infrastructure and IRSA roles"
  type        = bool
  default     = true
}

#####################################
# IAM IDENTITY CENTER CONFIGURATION
#####################################

variable "identity_center_instance_arn" {
  description = "ARN of the AWS Identity Center instance"
  type        = string
}

variable "poc_account_id" {
  description = "AWS Account ID for POC environment"
  type        = string
}

variable "permission_sets" {
  description = "Custom permission sets and account assignments for POC"
  type = map(object({
    description      = string
    session_duration = optional(string, "PT8H")
    access_level     = string
    
    account_assignments = optional(list(object({
      principal_id   = string
      principal_type = string
      target_id      = string
      target_type    = string
    })), [])
  }))
  default = {}
}
