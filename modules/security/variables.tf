# Security Module Variables - Enterprise Security and Compliance Configuration

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

#OIDC provider provides trust relationship for the pod to assume IAM role without storing AWS credentials. It works as below.
#1.Pod starts with Service account annotation (specifying IAM role ARN)
#2.EKS injects OIDC token into pod
#3.pod calls AWS API - AWS STS validates token against OIDC provider.If valid, pod assumes IAM role in the token specified in ServiceAccount annotation. 
variable "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN (empty until EKS is deployed)"
  type        = string
  default     = ""
}

# KMS Configuration
variable "kms_keys" {
  description = "Map of KMS keys to create for encryption"
  type = map(object({
    description             = string
    purpose                = string
    key_usage              = optional(string, "ENCRYPT_DECRYPT")
    key_spec               = optional(string, "SYMMETRIC_DEFAULT")
    enable_key_rotation    = optional(bool, true)
	policy                 = optional(string)
  }))
  default = {
	#commented for cost savings in this POC
    /*"security-logs" = {
      description = "KMS key for security logs encryption"
      purpose     = "security-logging"
    }*/
    "eks-secrets" = {
      description = "KMS key for EKS secrets encryption - Service Only Access"
	  purpose     = "eks-encryption"
	  policy = jsonencode({
		Version = "2012-10-17"
		Statement = concat([
			{
			  Sid = "AllowEKSService"
			  Effect = "Allow"
			  Principal = { Service = "eks.amazonaws.com" }
			  Action = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*"]
			  Resource = "*"
			}
		  ], var.eks_oidc_provider_arn != "" ? [{
			Sid = "AllowPodServiceAccounts"
			Effect = "Allow"
			Principal = { Federated = var.eks_oidc_provider_arn }
			Action = ["kms:Decrypt", "kms:DescribeKey"]
			Resource = "*"
			Condition = {
			  StringEquals = {
				"${replace(var.eks_oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")}:sub" = "system:serviceaccount:default:my-app"
			  }
			}
		  }] : [])
	  })
    }
	#commented for cost savings in this POC
    /*"backup" = {
      description = "KMS key for backup encryption"
      purpose     = "backup-encryption"
    }*/
  }
}

variable "enable_log_encryption" {
  description = "Enable KMS encryption for all security logs"
  type        = bool
  default     = true
}

variable "security_log_retention_days" {
  description = "Number of days to retain security logs"
  type        = number
  default     = 90
  
  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.security_log_retention_days)
    error_message = "Invalid log retention period. Check AWS CloudWatch documentation for valid values."
  }
}

# GuardDuty Configuration
variable "enable_guardduty" {
  description = "Enable Amazon GuardDuty threat detection"
  type        = bool
  #diabled to save cost in POC
  default     = false
}

variable "guardduty_finding_frequency" {
  description = "Frequency of GuardDuty findings publication to CloudWatch Events"
  type        = string
  default     = "FIFTEEN_MINUTES"
  
  validation {
    condition = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.guardduty_finding_frequency)
    error_message = "Finding frequency must be one of: FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS."
  }
}

variable "guardduty_datasources" {
  description = "GuardDuty data sources configuration - Enterprise complete with cost controls"
  
  type = object({
    # S3 Protection - monitors S3 API calls for threats ($0.10 per 1M API calls)
    # Disabled by default for POC cost optimization
    s3_logs            = optional(bool, false)
    
    # Kubernetes Protection - monitors EKS for container threats ($0.015 per audit log)
    # Disabled by default for POC cost optimization 
    kubernetes         = optional(bool, false)
    
    # Malware Protection - scans EBS volumes when suspicious activity detected
    # Disabled by default for POC cost optimization (~$0.10 per GB scanned)
    malware_protection = optional(bool, false)
  })
  default = {}
}

variable "guardduty_kubernetes_features" {
  description = "GuardDuty Kubernetes feature configuration - Enterprise granular controls"
  
  type = object({
    # EKS Audit Logs - monitors Kubernetes API calls for threats
    # Standard cost included in kubernetes datasource
    audit_logs = optional(bool, true)
    
    # EKS Runtime Monitoring - monitors running containers for threats  
    # Higher cost - separate control for enterprise flexibility (~$2 per node per month)
    runtime_monitoring = optional(bool, false)
    
    # EKS Add-on Management - enhanced monitoring of EKS add-ons when runtime monitoring enabled
    # Additional monitoring capability for managed EKS add-ons
    eks_addon_management = optional(bool, false)
  })
  default = {}
}

# Security Hub Configuration
variable "enable_security_hub" {
  description = "Enable AWS Security Hub"
  type        = bool
  default     = false
}

variable "security_hub_enable_default_standards" {
  description = "Enable default Security Hub standards"
  type        = bool
  default     = false
}

variable "security_hub_auto_enable_controls" {
  description = "Automatically enable new controls when they are added to standards"
  type        = bool
  default     = true
}

variable "security_hub_standards" {
  description = "Map of Security Hub standards to enable"
  type = map(object({
    standards_arn = string
  }))
  default = {
    "aws-foundational" = {
      standards_arn = "arn:aws:securityhub:::ruleset/finding-format/aws-foundational-security-standard"
    }
    "cis-aws-foundations" = {
      standards_arn = "arn:aws:securityhub:::ruleset/finding-format/cis-aws-foundations-benchmark"
    }
    "pci-dss" = {
      standards_arn = "arn:aws:securityhub:::ruleset/finding-format/pci-dss"
    }
  }
}

variable "security_hub_custom_insights" {
  description = "Custom Security Hub insights configuration"
  type = map(object({
    group_by_attribute = string
    filters = object({
      product_arn = optional(list(object({
        comparison = string
        value      = string
      })), [])
      severity_normalized = optional(list(object({
        gte = optional(number)
        lte = optional(number)
      })), [])
      compliance_status = optional(list(object({
        comparison = string
        value      = string
      })), [])
      resource_type = optional(list(object({
        comparison = string
        value      = string
      })), [])
      record_state = optional(list(object({
        comparison = string
        value      = string
      })), [])
      workflow_status = optional(list(object({
        comparison = string
        value      = string
      })), [])
      title = optional(list(object({
        comparison = string
        value      = string
      })), [])
      resource_id = optional(list(object({
        comparison = string
        value      = string
      })), [])
    })
  }))
  default = {}
}

variable "security_hub_action_targets" {
  description = "Security Hub action targets for automation"
  type = map(object({
    identifier  = string
    description = string
  }))
  default = {}
}

# AWS Config Configuration
variable "enable_config" {
  description = "Enable AWS Config for compliance monitoring"
  type        = bool
  default     = false
}

variable "config_monitor_all_resource_types" {
  description = "Monitor ALL supported AWS resource types (vs selective monitoring)"
  type        = bool
  default     = true  # Enterprise: comprehensive monitoring
}

variable "config_include_global_resource_types" {
  description = "Include global resources in Config recordings"
  type        = bool
  default     = true
}

variable "config_excluded_resource_types" {
  description = "List of resource types to exclude from Config"
  type        = list(string)
  default     = []
}

variable "config_recording_mode_overrides" {
  description = "Recording mode overrides for specific resource types"
  type = list(object({
    description         = string
    resource_types     = list(string)
    recording_frequency = string
  }))
  default = []
}

variable "config_delivery_frequency" {
  description = "Delivery frequency for Config snapshots"
  type        = string
  default     = "TwentyFour_Hours"
  
  validation {
    condition = contains(["One_Hour", "Three_Hours", "Six_Hours", "Twelve_Hours", "TwentyFour_Hours"], var.config_delivery_frequency)
    error_message = "Delivery frequency must be one of: One_Hour, Three_Hours, Six_Hours, Twelve_Hours, TwentyFour_Hours."
  }
}

variable "config_sns_notifications" {
  description = "Enable SNS notifications for Config"
  type        = bool
  default     = false
}

variable "config_force_destroy" {
  description = "Force destroy Config S3 bucket on deletion"
  type        = bool
  default     = false
}

variable "config_rules" {
  description = "Map of AWS Config rules to create"
  type = map(object({
    source_owner      = string
    source_identifier = string
    input_parameters  = optional(string)
    source_details = optional(list(object({
      event_source                = optional(string)
      message_type               = optional(string)
      maximum_execution_frequency = optional(string)
    })), [])
  }))
  default = {
	#All EBS volumes must be encrypted
    "encrypted-volumes" = {
      source_owner      = "AWS"
      source_identifier = "ENCRYPTED_VOLUMES"
    }
	#check if AWS root account should NOT have access keys
    "root-access-key-check" = {
      source_owner      = "AWS"
      source_identifier = "ROOT_ACCESS_KEY_CHECK"
    }
	#Account has strong password policy configured
    "iam-password-policy" = {
      source_owner      = "AWS"
      source_identifier = "IAM_PASSWORD_POLICY"
    }
	#CloudTrail is enabled and logging 
    "cloudtrail-enabled" = {
      source_owner      = "AWS"
      source_identifier = "CLOUD_TRAIL_ENABLED"
    }
  }
}

# CloudTrail Configuration
variable "enable_cloudtrail" {
  description = "Enable AWS CloudTrail for audit logging"
  type        = bool
  default     = false
}

variable "cloudtrail_multi_region" {
  description = "Enable multi-region CloudTrail"
  type        = bool
  default     = true
}

variable "cloudtrail_cloudwatch_logs" {
  description = "Enable CloudWatch Logs integration for CloudTrail"
  type        = bool
  default     = true
}

variable "cloudtrail_force_destroy" {
  description = "Force destroy CloudTrail S3 bucket on deletion"
  type        = bool
  default     = false
}

variable "cloudtrail_event_selectors" {
  description = "Event selectors for CloudTrail"
  type = list(object({
    read_write_type           = optional(string, "All")
    include_management_events = optional(bool, true)
    data_resources = optional(list(object({
      type   = string
      values = list(string)
    })), [])
  }))
  default = [
    {
      read_write_type           = "All"
      include_management_events = true
      data_resources = [
        {
          type   = "AWS::S3::Object"
          values = ["arn:aws:s3:::*/*"]
        }
      ]
    }
  ]
}

# Security Events Configuration
variable "enable_security_events" {
  description = "Enable EventBridge rules for security events"
  type        = bool
  default     = true
}

variable "security_hub_event_rules" {
  description = "EventBridge rules for Security Hub findings"
  type = map(object({
    description      = string
    detail_types     = list(string)
    compliance_status = optional(list(string), ["FAILED"])
    severity_range   = optional(list(number), [70, 100])
    product_names    = optional(list(string))
    enabled          = optional(bool, true)
    actions_required = optional(list(string), ["Review and remediate"])
  }))
  default = {
    "high-severity-findings" = {
      description   = "High severity security findings"
      detail_types  = ["Security Hub Findings - Imported"]
      severity_range = [70, 100]
    }
    "compliance-failures" = {
      description      = "Compliance check failures"
      detail_types     = ["Security Hub Findings - Imported"]
      compliance_status = ["FAILED"]
    }
  }
}

variable "security_alert_subscriptions" {
  description = "SNS topic subscriptions for security alerts"
  type = map(object({
    protocol      = string
    endpoint      = string
    filter_policy = optional(map(any))
  }))
  default = {}
}

# Security Automation
variable "enable_security_automation" {
  description = "Enable Lambda-based security automation"
  type        = bool
  default     = false
}

variable "security_automation_lambda_zip" {
  description = "Path to Lambda function ZIP file for security automation"
  type        = string
  default     = null
}

variable "security_automation_lambda_handler" {
  description = "Lambda function handler"
  type        = string
  default     = "index.handler"
}

variable "security_automation_lambda_runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "python3.11"
}

variable "security_automation_lambda_env_vars" {
  description = "Environment variables for security automation Lambda"
  type        = map(string)
  default     = {}
}

variable "security_automation_vpc_config" {
  description = "VPC configuration for security automation Lambda"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

# Inspector Configuration
variable "enable_inspector" {
  description = "Enable Amazon Inspector for vulnerability assessment"
  type        = bool
  default     = true
}

variable "inspector_resource_types" {
  description = "Inspector resource types to scan"
  type        = list(string)
  default     = ["ECR", "EC2"]
  
  validation {
    condition = alltrue([
      for type in var.inspector_resource_types : contains(["ECR", "EC2", "LAMBDA"], type)
    ])
    error_message = "Inspector resource types must be ECR, EC2, or LAMBDA."
  }
}

# Incident Response Configuration
variable "enable_incident_response_role" {
  description = "Enable incident response IAM role"
  type        = bool
  default     = false
}

variable "incident_response_trusted_principals" {
  description = "List of trusted principal ARNs for incident response role"
  type        = list(string)
  default     = []
}

# Cross-Account Security Audit
variable "enable_cross_account_audit" {
  description = "Enable cross-account security audit role"
  type        = bool
  default     = false
}

variable "security_audit_trusted_accounts" {
  description = "List of trusted AWS account IDs for security audit"
  type        = list(string)
  default     = []
}

variable "security_audit_external_id" {
  description = "External ID for cross-account security audit role"
  type        = string
  default     = null
}

# Compliance Configuration
variable "compliance_frameworks" {
  description = "List of compliance frameworks to align with"
  type        = list(string)
  default     = ["SOC2", "PCI-DSS"]
  
  validation {
    condition = alltrue([
      for framework in var.compliance_frameworks : contains(["SOC2", "PCI-DSS", "HIPAA", "FedRAMP", "ISO27001", "NIST"], framework)
    ])
    error_message = "Invalid compliance framework. Supported: SOC2, PCI-DSS, HIPAA, FedRAMP, ISO27001, NIST."
  }
}

# Advanced Security Features
variable "enable_macie" {
  description = "Enable Amazon Macie for data security and privacy"
  type        = bool
  default     = false
}

variable "enable_detective" {
  description = "Enable Amazon Detective for security investigation"
  type        = bool
  default     = false
}

variable "enable_network_firewall" {
  description = "Enable AWS Network Firewall for network protection"
  type        = bool
  default     = false
}