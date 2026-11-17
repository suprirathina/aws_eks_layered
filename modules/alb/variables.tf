# ALB Module Variables

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
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for internet-facing ALB"
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for internal ALB"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ALB Configuration
variable "internal" {
  description = "Whether the ALB is internal (true) or internet-facing (false)"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for the ALB"
  type        = bool
  default     = false  # Disabled for POC environments
}

# Network Access Control
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "custom_ports" {
  description = "Custom ports to allow access to"
  type = list(object({
    port        = number
    description = string
  }))
  default = []
}

# HTTP/HTTPS Configuration
variable "enable_http" {
  description = "Enable HTTP listener"
  type        = bool
  default     = true
}

variable "enable_https" {
  description = "Enable HTTPS listener"
  type        = bool
  default     = false
}

variable "redirect_http_to_https" {
  description = "Redirect HTTP traffic to HTTPS"
  type        = bool
  default     = false
}

variable "ssl_certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS listener"
  type        = string
  default     = ""
}

variable "ssl_policy" {
  description = "SSL policy for HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

# Access Logs Configuration
variable "enable_access_logs" {
  description = "Enable ALB access logs to S3"
  type        = bool
  default     = false  # Disabled for cost optimization
}

variable "access_logs_retention_days" {
  description = "Number of days to retain access logs"
  type        = number
  default     = 30
}

# CloudWatch Integration Configuration
variable "enable_cloudwatch_integration" {
  description = "Enable ALB access log processing and integration with CloudWatch"
  type        = bool
  default     = false  # Disabled by default for cost control
}

variable "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for processed ALB metrics (auto-generated if not provided)"
  type        = string
  default     = null
}

# Advanced CloudWatch Integration Options
variable "enable_lambda_tracing" {
  description = "Enable AWS X-Ray tracing for Lambda function"
  type        = bool
  default     = false
}

variable "enable_scheduled_processing" {
  description = "Enable scheduled processing of ALB logs (in addition to real-time)"
  type        = bool
  default     = false
}

variable "lambda_memory_size" {
  description = "Memory allocation for Lambda function (MB)"
  type        = number
  default     = 128
  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 3008
    error_message = "Lambda memory size must be between 128 MB and 3008 MB."
  }
}

variable "lambda_timeout" {
  description = "Timeout for Lambda function (seconds)"
  type        = number
  default     = 300
  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "lambda_trigger_mode" {
  description = "Lambda trigger mode: immediate (S3 events) or batched (scheduled)"
  type        = string
  default     = "batched"
  validation {
    condition     = contains(["immediate", "batched"], var.lambda_trigger_mode)
    error_message = "Lambda trigger mode must be 'immediate' or 'batched'."
  }
}

variable "batch_processing_interval" {
  description = "Interval for batched processing mode (minutes)"
  type        = number
  default     = 15
  validation {
    condition     = var.batch_processing_interval >= 5 && var.batch_processing_interval <= 1440
    error_message = "Batch processing interval must be between 5 and 1440 minutes."
  }
}

# Target Groups Configuration
variable "target_groups" {
  description = "Map of target groups to create"
  type = map(object({
    port        = number
    protocol    = string
    target_type = string
    health_check = object({
      enabled             = bool
      healthy_threshold   = number
      interval            = number
      matcher             = string
      path                = string
      port                = string
      protocol            = string
      timeout             = number
      unhealthy_threshold = number
    })
    stickiness = optional(object({
      enabled         = bool
      type            = string
      cookie_duration = number
    }))
  }))
  default = {
    default = {
      port        = 80
      protocol    = "HTTP"
      target_type = "ip"
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        interval            = 30
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }
      stickiness = null
    }
  }
}

variable "default_target_group_key" {
  description = "Key of the target group to use as default for listeners"
  type        = string
  default     = "default"
}

# Listener Rules Configuration
variable "listener_rules" {
  description = "Map of listener rules to create"
  type = map(object({
    priority = number
    action = object({
      type             = string  # "forward", "redirect", "fixed-response"
      target_group_key = optional(string)
      redirect = optional(object({
        port        = optional(string)
        protocol    = optional(string)
        status_code = string
        host        = optional(string)
        path        = optional(string)
        query       = optional(string)
      }))
      fixed_response = optional(object({
        content_type = string
        message_body = string
        status_code  = string
      }))
    })
    conditions = list(object({
      type   = string  # "path-pattern", "host-header"
      values = list(string)
    }))
  }))
  default = {}
}

# Example default rules for common patterns
variable "create_default_rules" {
  description = "Create default listener rules for common patterns"
  type        = bool
  default     = true
}