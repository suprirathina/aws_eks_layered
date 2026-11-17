# EKS Module Variables - Enterprise Configuration

# Cluster Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$", var.cluster_name))
    error_message = "Cluster name must contain only alphanumeric characters and hyphens, and cannot start or end with a hyphen."
  }
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
  
  validation {
    condition = can(regex("^1\\.(2[4-9]|[3-9][0-9])$", var.cluster_version))
    error_message = "Cluster version must be 1.24 or higher."
  }
}

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

# Network Configuration
variable "vpc_id" {
  description = "VPC ID where the cluster will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)
  
  validation {
    condition = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnets are required for EKS cluster."
  }
}

variable "node_group_subnet_ids" {
  description = "List of subnet IDs for EKS managed node groups"
  type        = list(string)
  default     = null
}

variable "fargate_subnet_ids" {
  description = "List of subnet IDs for Fargate profiles (must be private)"
  type        = list(string)
  default     = []
}

# Cluster Endpoint Configuration
variable "endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Security Configuration
variable "enable_cluster_encryption" {
  description = "Enable encryption of Kubernetes secrets with KMS"
  type        = bool
  default     = true
}

variable "kms_key_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7
  
  validation {
    condition = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "KMS key deletion window must be between 7 and 30 days."
  }
}

variable "cluster_service_ipv4_cidr" {
  description = "Service IPv4 CIDR for the cluster"
  type        = string
  default     = null
  
  validation {
    condition = var.cluster_service_ipv4_cidr == null ? true : can(cidrhost(var.cluster_service_ipv4_cidr, 0))
    error_message = "cluster_service_ipv4_cidr must be a valid IPv4 CIDR block."
  }
}

# Logging Configuration
variable "cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  
  validation {
    condition = alltrue([
      for log_type in var.cluster_log_types : contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], log_type)
    ])
    error_message = "Invalid log type. Allowed values: api, audit, authenticator, controllerManager, scheduler."
  }
}

variable "cloudwatch_log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
  
  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cloudwatch_log_retention_days)
    error_message = "Invalid log retention period. Check AWS CloudWatch documentation for valid values."
  }
}

# Access Configuration
variable "authentication_mode" {
  description = "Authentication mode for the cluster"
  type        = string
  default     = "API"  
  
  validation {
    condition = contains(["CONFIG_MAP", "API", "API_AND_CONFIG_MAP"], var.authentication_mode)
    error_message = "Authentication mode must be one of: CONFIG_MAP, API, API_AND_CONFIG_MAP."
  }
}

variable "bootstrap_cluster_creator_admin_permissions" {
  description = "Bootstrap cluster creator admin permissions"
  type        = bool
  default     = true
}

variable "access_entries" {
  description = "Map of EKS access entries"
  type = map(object({
    principal_arn     = string
    kubernetes_groups = optional(list(string), [])
    type             = optional(string, "STANDARD")
    policy_associations = optional(list(object({
      policy_arn = string
      access_scope = object({
        type       = string
        namespaces = optional(list(string))
      })
    })), [])
  }))
  default = {}
}

# Node Groups Configuration
variable "managed_node_groups" {
  description = "Map of EKS managed node group definitions"
  type = map(object({
    instance_types               = list(string)
    capacity_type               = optional(string, "ON_DEMAND")
    ami_type                    = optional(string, "AL2_x86_64")
    disk_size                   = optional(number, 50)
    desired_capacity            = number
    max_capacity               = number
    min_capacity               = number
    max_unavailable_percentage = optional(number, 25)
    
    # Launch template
    launch_template = optional(object({
      id      = string
      version = string
    }))
    
    # Remote access (disabled by default for security)
    enable_remote_access        = optional(bool, false)
    key_name                   = optional(string)
    source_security_group_ids  = optional(list(string))
    
    # Taints and labels
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    
    labels = optional(map(string), {})
  }))
  default = {}
}

# Fargate Profiles Configuration
variable "fargate_profiles" {
  description = "Map of EKS Fargate profile definitions"
  type = map(object({
    selectors = list(object({
      namespace = string
      labels    = optional(map(string), {})
    }))
  }))
  default = {}
}

# EKS Add-ons Configuration
variable "cluster_addons" {
  description = "Map of EKS cluster addons"
  type = map(object({
    addon_version            = optional(string)
    service_account_role_arn = optional(string)
    resolve_conflicts       = optional(string, "OVERWRITE")
    configuration_values    = optional(string)
  }))
  default = {
    coredns = {
      addon_version = null
    }
    kube-proxy = {
      addon_version = null
    }
    vpc-cni = {
      addon_version = null
    }
  }
}

# Security Groups
variable "additional_security_group_ids" {
  description = "List of additional security group IDs to associate with the cluster"
  type        = list(string)
  default     = []
}

variable "create_additional_security_group" {
  description = "Create additional security group for the cluster"
  type        = bool
  default     = false
}

variable "additional_security_group_rules" {
  description = "Additional security group rules for the cluster"
  type = map(object({
    from_port                = number
    to_port                  = number
    protocol                 = string
    source_security_group_id = optional(string)
    cidr_blocks             = optional(list(string))
    description             = optional(string)
  }))
  default = {}
}

# IRSA Configuration for Add-ons
variable "enable_aws_load_balancer_controller" {
  description = "Create IRSA role for AWS Load Balancer Controller"
  type        = bool
  default     = false
}

variable "enable_cluster_autoscaler" {
  description = "Create IRSA role for Cluster Autoscaler"
  type        = bool
  default     = false
}

variable "enable_ebs_csi_driver" {
  description = "Create IRSA role for EBS CSI Driver"
  type        = bool
  default     = false
}

variable "enable_external_secrets" {
  description = "Create IRSA role for External Secrets Operator"
  type        = bool
  default     = false
}

# External Secrets Configuration
variable "secrets_manager_prefix" {
  description = "Prefix for Secrets Manager secrets that External Secrets can access"
  type        = string
  default     = "eks/"
}

variable "parameter_store_prefix" {
  description = "Prefix for Parameter Store parameters that External Secrets can access"
  type        = string
  default     = "eks/"
}