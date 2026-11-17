# IAM Module Variables - Enterprise Identity and Access Management

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Identity Center Configuration
variable "identity_center_instance_arn" {
  description = "ARN of the AWS Identity Center instance"
  type        = string
}

# EKS OIDC Provider for IRSA roles
variable "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN for IRSA role trust policies"
  type        = string
  default     = ""
}

variable "permission_sets" {
  description = "Map of Identity Center permission sets and their configuration"
  type = map(object({
    description      = string
    session_duration = optional(string, "PT8H")  # 8 hours default
    access_level     = string  # ReadOnly, PowerUser, Administrator, etc.
    
    # AWS Managed Policies
    aws_managed_policies = optional(list(string), [])
    
    # Customer Managed Policies
    customer_managed_policies = optional(list(object({
      name = string
      path = optional(string, "/")
    })), [])
    
    # Inline Policy (JSON string)
    inline_policy = optional(string)
    
    # Account Assignments
    account_assignments = optional(list(object({
      principal_id   = string       # User ID or Group ID from Identity Center
      principal_type = string       # USER or GROUP
      target_id      = string       # AWS Account ID
      target_type    = string       # AWS_ACCOUNT
    })), [])
  }))
  default = {}
}

# Custom IAM Policies
variable "custom_policies" {
  description = "Map of custom IAM policies to create"
  type = map(object({
    description     = string
    path           = optional(string, "/")
    policy_document = string  # JSON policy document
  }))
  default = {}
}

# Predefined EKS Roles Templates
variable "enable_default_eks_roles" {
  description = "Create default EKS infrastructure and IRSA roles for common patterns"
  type        = bool
  default     = true
}

variable "default_eks_roles_config" {
  description = "Configuration for default EKS roles"
  type = object({
    create_cluster_service_role     = optional(bool, true)
    create_node_group_role         = optional(bool, true)  
    create_alb_controller_irsa     = optional(bool, true)
    create_external_secrets_irsa   = optional(bool, true)
    create_ebs_csi_driver_irsa     = optional(bool, true)
    create_cluster_autoscaler_irsa = optional(bool, true)
    create_fluent_bit_irsa         = optional(bool, false)  # Optional
    create_adot_collector_irsa     = optional(bool, false)  # Optional
  })
  default = {}
}

# EKS-specific IAM Roles
variable "eks_roles" {
  description = "Map of EKS-related IAM roles to create"
  type = map(object({
    path                 = optional(string, "/")
    purpose              = string
    max_session_duration = optional(number, 3600)
    
    # Trust policy configuration
    principal = object({
      Service   = optional(list(string))
      AWS       = optional(list(string))
      Federated = optional(string)
    })
    
    conditions = optional(map(any), {})
    
    # Managed policies to attach
    managed_policies = optional(list(string), [])
    
    # Inline policies (name -> JSON document)
    inline_policies = optional(map(string), {})
  }))
  default = {}
}

# Cross-Account IAM Roles
variable "cross_account_roles" {
  description = "Map of cross-account IAM roles to create"
  type = map(object({
    path                 = optional(string, "/cross-account/")
    purpose              = string
    max_session_duration = optional(number, 3600)
    trusted_accounts     = list(string)  # List of AWS account IDs
    conditions          = optional(map(any), {})
    managed_policies    = optional(list(string), [])
    inline_policies     = optional(map(string), {})
  }))
  default = {}
}

# Service-Linked Roles
variable "service_linked_roles" {
  description = "Map of AWS service-linked roles to create"
  type = map(object({
    service_name  = string
    description   = string
    custom_suffix = optional(string)
  }))
  default = {}
}

# OIDC Identity Providers
variable "oidc_providers" {
  description = "Map of OIDC identity providers to create"
  type = map(object({
    url           = string
    client_ids    = list(string)
    thumbprints   = list(string)
    provider_name = string
  }))
  default = {}
}

# Security Configuration
variable "enable_password_policy" {
  description = "Enable IAM account password policy"
  type        = bool
  default     = true
}

variable "password_policy" {
  description = "IAM account password policy configuration"
  type = object({
    minimum_length           = optional(number, 14)
    require_lowercase        = optional(bool, true)
    require_numbers         = optional(bool, true)
    require_uppercase       = optional(bool, true)
    require_symbols         = optional(bool, true)
    allow_users_to_change   = optional(bool, true)
    hard_expiry             = optional(bool, false)
    max_age                 = optional(number, 90)
    reuse_prevention        = optional(number, 12)
  })
  default = {}
}

variable "enable_access_analyzer" {
  description = "Enable IAM Access Analyzer for security monitoring"
  type        = bool
  default     = true
}

variable "access_analyzer_log_retention" {
  description = "CloudWatch log retention for Access Analyzer findings"
  type        = number
  default     = 90
  
  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.access_analyzer_log_retention)
    error_message = "Invalid log retention period. Check AWS CloudWatch documentation for valid values."
  }
}

# Break Glass Emergency Access
variable "enable_break_glass_role" {
  description = "Enable emergency break glass role for critical incidents"
  type        = bool
  default     = false
}

variable "break_glass_trusted_principals" {
  description = "List of trusted principal ARNs that can assume the break glass role"
  type        = list(string)
  default     = []
}

# Predefined Permission Set Templates
variable "enable_default_permission_sets" {
  description = "Create default permission sets for common access patterns"
  type        = bool
  default     = true
}

variable "default_permission_sets_config" {
  description = "Configuration for default permission sets"
  type = object({
    create_readonly_access    = optional(bool, true)
    create_poweruser_access   = optional(bool, true)
    create_admin_access       = optional(bool, true)
    create_billing_access     = optional(bool, false)
    create_security_audit     = optional(bool, true)
    create_eks_admin         = optional(bool, true)
    create_eks_developer     = optional(bool, true)
    create_eks_viewer        = optional(bool, true)
  })
  default = {}
}

# Compliance and Security
variable "enable_cloudtrail_integration" {
  description = "Enable CloudTrail integration for IAM events"
  type        = bool
  default     = true
}

variable "enable_config_integration" {
  description = "Enable AWS Config integration for IAM compliance monitoring"
  type        = bool
  default     = true
}

variable "compliance_frameworks" {
  description = "List of compliance frameworks to align with"
  type        = list(string)
  default     = ["SOC2", "PCI-DSS"]
  
  validation {
    condition = alltrue([
      for framework in var.compliance_frameworks : contains(["SOC2", "PCI-DSS", "HIPAA", "FedRAMP", "ISO27001"], framework)
    ])
    error_message = "Invalid compliance framework. Supported: SOC2, PCI-DSS, HIPAA, FedRAMP, ISO27001."
  }
}

# Multi-Account Organization Support
variable "organization_config" {
  description = "AWS Organizations configuration for multi-account setup"
  type = object({
    management_account_id = optional(string)
    organizational_units  = optional(map(object({
      name        = string
      policy_arns = optional(list(string), [])
    })), {})
    
    # Cross-account access patterns
    central_logging_account   = optional(string)
    security_account         = optional(string)
    shared_services_account  = optional(string)
  })
  default = {}
}

# Advanced Security Features
variable "enable_privileged_access_management" {
  description = "Enable advanced privileged access management features"
  type        = bool
  default     = false
}

variable "privileged_access_config" {
  description = "Configuration for privileged access management"
  type = object({
    require_mfa_for_admin     = optional(bool, true)
    max_session_duration      = optional(number, 3600)  # 1 hour
    require_ip_restriction    = optional(bool, false)
    allowed_ip_ranges         = optional(list(string), [])
    require_time_restriction  = optional(bool, false)
    allowed_time_ranges       = optional(list(string), [])
  })
  default = {}
}