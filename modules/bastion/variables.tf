# Bastion Module Variables

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
  description = "VPC ID where bastion will be created"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID for bastion host"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Networking Configuration
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to bastion host"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict in production
}

# Instance Configuration
variable "instance_type" {
  description = "EC2 instance type for bastion host"
  type        = string
  default     = "t3.nano"
  
  validation {
    condition = contains([
      "t3.nano", "t3.micro", "t3.small", "t3.medium",
      "t2.nano", "t2.micro", "t2.small", "t2.medium"
    ], var.instance_type)
    error_message = "Instance type must be a valid t2 or t3 instance for cost efficiency."
  }
}

variable "ami_id" {
  description = "AMI ID for bastion host (leave empty to use latest Amazon Linux 2023)"
  type        = string
  default     = ""
}

variable "ec2_key_pair_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
}

# EKS Integration
variable "cluster_name" {
  description = "EKS cluster name for kubectl configuration"
  type        = string
}

variable "cluster_arn" {
  description = "EKS cluster ARN for IAM policy (optional - defaults to wildcard)"
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS region"
  type        = string
}

# Feature Flags
variable "use_elastic_ip" {
  description = "Whether to create and associate an Elastic IP"
  type        = bool
  default     = false  # Cost optimization - use dynamic public IP
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true  # Useful for reference architecture
}

variable "auto_shutdown" {
  description = "Whether this resource should be included in auto-shutdown for cost optimization"
  type        = bool
  default     = true  # Bastion can be shutdown when not in use
}

# Custom Scripts
variable "user_data_script" {
  description = "Custom user data script (overrides default if provided)"
  type        = string
  default     = ""
}