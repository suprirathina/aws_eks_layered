# ECR Module Variables

# Required Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod, micro)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Repository Configuration
variable "repositories" {
  description = "Map of ECR repositories to create"
  type = map(object({
    image_tag_mutability = string  # "MUTABLE" or "IMMUTABLE"
    scan_on_push         = bool
    encryption_type      = string  # "AES256" or "KMS"
    kms_key_id          = optional(string)
    force_delete        = bool
    application         = string
    lifecycle_policy = optional(object({
      rules = list(object({
        rulePriority = number
        description  = string
        selection = object({
          tagStatus     = string
          tagPrefixList = optional(list(string))
          countType     = string
          countUnit     = optional(string)
          countNumber   = number
        })
        action = object({
          type = string
        })
      }))
    }))
    cross_account_access = optional(object({
      principals = list(string)
      actions    = list(string)
    }))
  }))
  default = {
    frontend = {
      image_tag_mutability = "MUTABLE"
      scan_on_push         = true
      encryption_type      = "AES256"
      force_delete        = false
      application         = "frontend"
      lifecycle_policy = {
        rules = [
          {
            rulePriority = 1
            description  = "Keep last 10 production images"
            selection = {
              tagStatus     = "tagged"
              tagPrefixList = ["prod", "production", "release"]
              countType     = "imageCountMoreThan"
              countNumber   = 10
            }
            action = {
              type = "expire"
            }
          },
          {
            rulePriority = 2
            description  = "Delete untagged images after 1 day"
            selection = {
              tagStatus   = "untagged"
              countType   = "sinceImagePushed"
              countUnit   = "days"
              countNumber = 1
            }
            action = {
              type = "expire"
            }
          }
        ]
      }
    }
    backend = {
      image_tag_mutability = "MUTABLE"
      scan_on_push         = true
      encryption_type      = "AES256"
      force_delete        = false
      application         = "backend"
      lifecycle_policy = {
        rules = [
          {
            rulePriority = 1
            description  = "Keep last 10 production images"
            selection = {
              tagStatus     = "tagged"
              tagPrefixList = ["prod", "production", "release"]
              countType     = "imageCountMoreThan"
              countNumber   = 10
            }
            action = {
              type = "expire"
            }
          },
          {
            rulePriority = 2
            description  = "Delete untagged images after 1 day"
            selection = {
              tagStatus   = "untagged"
              countType   = "sinceImagePushed"
              countUnit   = "days"
              countNumber = 1
            }
            action = {
              type = "expire"
            }
          }
        ]
      }
    }
  }
}

# Pull-Through Cache Configuration
variable "enable_pull_through_cache" {
  description = "Enable ECR pull-through cache for external registries"
  type        = bool
  default     = false
}

variable "pull_through_cache_rules" {
  description = "Pull-through cache rules for external registries"
  type = map(object({
    repository_prefix     = string
    upstream_registry_url = string
    credential_arn        = optional(string)
  }))
  default = {
    dockerhub = {
      repository_prefix     = "dockerhub"
      upstream_registry_url = "registry-1.docker.io"
      credential_arn        = null
    }
    public_ecr = {
      repository_prefix     = "ecr-public"
      upstream_registry_url = "public.ecr.aws"
      credential_arn        = null
    }
  }
}

# Scanning Configuration
variable "enable_scan_logging" {
  description = "Enable CloudWatch logging for ECR image scan results"
  type        = bool
  default     = false
}

variable "scan_log_retention_days" {
  description = "Number of days to retain scan logs"
  type        = number
  default     = 3
}

variable "scan_log_kms_key_id" {
  description = "KMS key ID for encrypting scan logs"
  type        = string
  default     = null
}

variable "enable_registry_scanning" {
  description = "Enable registry-wide scanning configuration"
  type        = bool
  default     = false
}

variable "registry_scan_type" {
  description = "Type of registry scanning (BASIC or ENHANCED)"
  type        = string
  default     = "BASIC"
  
  validation {
    condition     = contains(["BASIC", "ENHANCED"], var.registry_scan_type)
    error_message = "Registry scan type must be either BASIC or ENHANCED."
  }
}

variable "registry_scan_rules" {
  description = "Registry scanning rules"
  type = list(object({
    scan_frequency     = string
    repository_filter  = string
    filter_type       = string
  }))
  default = []
}

# Replication Configuration
variable "enable_replication" {
  description = "Enable ECR replication to other regions"
  type        = bool
  default     = false
}

variable "replication_rules" {
  description = "ECR replication rules"
  type = list(object({
    destinations = list(object({
      region      = string
      registry_id = string
    }))
    repository_filters = list(object({
      filter      = string
      filter_type = string
    }))
  }))
  default = []
}

# KMS Configuration
variable "create_kms_key" {
  description = "Create a KMS key for ECR encryption"
  type        = bool
  default     = false
}

variable "kms_key_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7
}