# VPC Endpoints Module Variables

# Required Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod, micro)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where endpoints will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for interface endpoints"
  type        = list(string)
  default     = []
}

variable "route_table_ids" {
  description = "List of route table IDs for gateway endpoints"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Network Security Configuration
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access VPC endpoints"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "allow_http_access" {
  description = "Allow HTTP access to VPC endpoints (in addition to HTTPS)"
  type        = bool
  default     = false
}

variable "custom_ingress_rules" {
  description = "Additional ingress rules for VPC endpoint security group"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = []
}

# VPC Endpoints Configuration
variable "vpc_endpoints" {
  description = "Map of VPC endpoints to create"
  type = map(object({
    service_name        = string
    endpoint_type      = string  # "Interface" or "Gateway"
    private_dns_enabled = optional(bool, true)
    policy             = optional(any, null)
  }))
  default = {
    s3 = {
      service_name        = "com.amazonaws.REGION.s3"
      endpoint_type      = "Gateway"
      private_dns_enabled = false
      policy = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = "*"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:DeleteObject",
              "s3:ListBucket"
            ]
            Resource = "*"
          }
        ]
      }
    }
    ecr_api = {
      service_name        = "com.amazonaws.REGION.ecr.api"
      endpoint_type      = "Interface"
      private_dns_enabled = true
      policy = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = "*"
            Action = [
              "ecr:GetAuthorizationToken",
              "ecr:BatchCheckLayerAvailability",
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage",
              "ecr:DescribeRepositories",
              "ecr:DescribeImages"
            ]
            Resource = "*"
          }
        ]
      }
    }
    ecr_dkr = {
      service_name        = "com.amazonaws.REGION.ecr.dkr"
      endpoint_type      = "Interface"
      private_dns_enabled = true
      policy = {
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = "*"
            Action = [
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage",
              "ecr:BatchCheckLayerAvailability"
            ]
            Resource = "*"
          }
        ]
      }
    }
  }
}

# Flow Logs Configuration
variable "enable_flow_logs" {
  description = "Enable VPC flow logs for endpoints"
  type        = bool
  default     = false
}

variable "flow_logs_iam_role_arn" {
  description = "IAM role ARN for VPC flow logs"
  type        = string
  default     = ""
}

variable "flow_logs_traffic_type" {
  description = "Type of traffic to capture in flow logs"
  type        = string
  default     = "ALL"
  
  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_logs_traffic_type)
    error_message = "Flow logs traffic type must be ACCEPT, REJECT, or ALL."
  }
}

variable "log_retention_days" {
  description = "Number of days to retain VPC endpoint logs"
  type        = number
  default     = 3
}

variable "log_kms_key_id" {
  description = "KMS key ID for log encryption"
  type        = string
  default     = null
}

# DNS Resolver Configuration
variable "enable_dns_resolver" {
  description = "Enable Route 53 DNS resolver for VPC endpoints"
  type        = bool
  default     = false
}

variable "dns_resolver_direction" {
  description = "Direction for DNS resolver endpoint"
  type        = string
  default     = "INBOUND"
  
  validation {
    condition     = contains(["INBOUND", "OUTBOUND"], var.dns_resolver_direction)
    error_message = "DNS resolver direction must be INBOUND or OUTBOUND."
  }
}

variable "dns_resolver_subnets" {
  description = "List of subnet IDs for DNS resolver endpoint"
  type        = list(string)
  default     = []
}

variable "dns_resolver_ips" {
  description = "Optional specific IPs for DNS resolver endpoint"
  type        = list(string)
  default     = null
}

variable "dns_resolver_rules" {
  description = "DNS resolver rules for custom domain forwarding"
  type = map(object({
    domain_name = string
    rule_type   = string  # "FORWARD", "SYSTEM", "RECURSIVE"
    target_ips = list(object({
      ip   = string
      port = optional(number, 53)
    }))
  }))
  default = {}
}

# Custom Endpoint Services
variable "custom_endpoint_services" {
  description = "Custom VPC endpoint services to create"
  type = map(object({
    acceptance_required        = bool
    network_load_balancer_arns = optional(list(string), [])
    gateway_load_balancer_arns = optional(list(string), [])
    allowed_principals         = optional(list(string), [])
    private_dns_name          = optional(string, null)
  }))
  default = {}
}

# Endpoint Connection Notifications
variable "endpoint_notifications" {
  description = "VPC endpoint connection notifications"
  type = map(object({
    vpc_endpoint_service_id = string
    notification_arn       = string
    connection_events      = list(string)
  }))
  default = {}
}

# Additional Security Group Rules
variable "additional_security_group_rules" {
  description = "Additional security group rules for specific endpoint requirements"
  type = map(object({
    type                     = string
    from_port               = number
    to_port                 = number
    protocol                = string
    cidr_blocks            = optional(list(string), [])
    source_security_group_id = optional(string, null)
    description            = string
  }))
  default = {}
}

# Region (for dynamic service name construction)
variable "region" {
  description = "AWS region (used to construct service names)"
  type        = string
  default     = ""
}