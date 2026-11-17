# Example Variables for Complete ALB Configuration

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "alb-example"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "ssl_certificate_arn" {
  description = "ARN of SSL certificate for HTTPS listener (optional)"
  type        = string
  default     = null
}