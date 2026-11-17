# Secrets Module Variables

# Required Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod, micro)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Secrets Configuration
variable "secrets" {
  description = "Map of secrets to create in AWS Secrets Manager"
  type = map(object({
    description             = string
    recovery_window_in_days = number
    application            = string
    secret_type           = string
    enable_rotation       = optional(bool, false)
    rotation_interval_days = optional(number, 90)
    kms_key_id           = optional(string, null)
    static_values        = optional(map(string), {})
    password_references  = optional(map(string), {})
    id_references       = optional(map(string), {})
    ignore_changes      = optional(bool, true)
    version_stages      = optional(list(string), ["AWSCURRENT"])
  }))
  default = {
    database = {
      description             = "Database connection credentials"
      recovery_window_in_days = 0
      application            = "backend"
      secret_type           = "database"
      static_values = {
        username = "app_user"
        host     = "localhost"
        port     = "5432"
        database = "app_db"
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
        jwt_issuer       = "secure-app"
        jwt_expiry_hours = "24"
        jwt_refresh_days = "30"
      }
      password_references = {
        jwt_secret_key  = "jwt_secret"
        jwt_refresh_key = "jwt_refresh"
      }
    }
  }
}

# Random Password Configuration
variable "random_passwords" {
  description = "Configuration for random password generation"
  type = map(object({
    length           = number
    special          = optional(bool, true)
    upper            = optional(bool, true)
    lower            = optional(bool, true)
    numeric          = optional(bool, true)
    override_special = optional(string, null)
    min_lower       = optional(number, null)
    min_upper       = optional(number, null)
    min_numeric     = optional(number, null)
    min_special     = optional(number, null)
    keepers         = optional(map(string), null)
  }))
  default = {
    db_password = {
      length  = 32
      special = true
    }
    auth0_secret = {
      length  = 64
      special = false
    }
    jwt_secret = {
      length  = 128
      special = true
    }
    jwt_refresh = {
      length  = 128
      special = true
    }
  }
}

# Random ID Configuration
variable "random_ids" {
  description = "Configuration for random ID generation"
  type = map(object({
    byte_length = number
    prefix      = optional(string, "")
    keepers     = optional(map(string), null)
  }))
  default = {
    api_suffix = {
      byte_length = 8
    }
  }
}

# External Secrets Operator Configuration
variable "enable_external_secrets_operator" {
  description = "Enable External Secrets Operator integration"
  type        = bool
  default     = true
}

variable "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN for External Secrets Operator"
  type        = string
  default     = ""
}

variable "external_secrets_service_account" {
  description = "Service account for External Secrets Operator"
  type        = string
  default     = "system:serviceaccount:external-secrets-system:external-secrets"
}

variable "external_secrets_additional_policies" {
  description = "Additional IAM policy ARNs for External Secrets Operator"
  type        = list(string)
  default     = []
}

# KMS Configuration
variable "create_kms_key" {
  description = "Create a KMS key for secrets encryption"
  type        = bool
  default     = false
}

variable "kms_key_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7
}

variable "kms_key_additional_principals" {
  description = "Additional principals allowed to use the KMS key"
  type        = list(string)
  default     = []
}

# Logging Configuration
variable "enable_access_logging" {
  description = "Enable CloudWatch logging for Secrets Manager access"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Number of days to retain access logs"
  type        = number
  default     = 3
}

variable "log_kms_key_id" {
  description = "KMS key ID for encrypting access logs"
  type        = string
  default     = null
}

# Lambda Rotation Functions
variable "rotation_functions" {
  description = "Lambda functions for secret rotation"
  type = map(object({
    filename              = string
    execution_role_arn   = string
    handler              = string
    runtime              = string
    timeout              = optional(number, 30)
    memory_size          = optional(number, 128)
    environment_variables = optional(map(string), {})
    vpc_config = optional(object({
      subnet_ids         = list(string)
      security_group_ids = list(string)
    }))
  }))
  default = {}
}

# Kubernetes Examples
variable "create_k8s_examples" {
  description = "Create Kubernetes secret examples file"
  type        = bool
  default     = true
}

# Cross-Region Replication
variable "secret_replications" {
  description = "Cross-region secret replication configuration"
  type = map(object({
    secret_key = string
    regions = list(object({
      region     = string
      kms_key_id = optional(string)
    }))
  }))
  default = {}
}

# Resource-Based Policies
variable "secret_policies" {
  description = "Resource-based policies for secrets"
  type = map(object({
    secret_key = string
    policy     = any
  }))
  default = {}
}