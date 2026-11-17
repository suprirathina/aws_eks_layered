# Enterprise Security Module - Comprehensive Security and Compliance
# GuardDuty, Config Rules, Security Hub, KMS, and security monitoring

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  # Common tags for all resources
  common_tags = merge(
    var.tags,
    {
      Module      = "security"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )

  # Account information
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  partition  = data.aws_partition.current.partition
}

# KMS Keys for Encryption
resource "aws_kms_key" "main" {
  for_each = var.kms_keys

  description = each.value.description
  key_usage   = each.value.key_usage
  key_spec    = each.value.key_spec

  # Security configuration
  enable_key_rotation = each.value.enable_key_rotation
  
  #to safeguard against accidental deletion - data encrypted with this deleted key also will be deleted along with the key, when key is deleted.
  #key is marked as "Pending deletion" state allowing oppertunity for revert deletion. 
  deletion_window_in_days = each.value.deletion_window_in_days

  # KMS key policy (resource-based) controlling access permissions
  # Defines: WHO (principals) can perform WHAT (actions) on this key
  # AWS Service account (AWS services) has internal permissions already granted. IAM roles need permissions that match key policy to work. 
  policy = each.value.policy

  tags = merge(local.common_tags, {
    Name    = each.key
    Purpose = each.value.purpose
  })
}

resource "aws_kms_alias" "main" {
  for_each = var.kms_keys

  name          = "alias/${var.environment}-${each.key}"
  target_key_id = aws_kms_key.main[each.key].key_id
}

# GuardDuty - Threat Detection
resource "aws_guardduty_detector" "main" {
  count = var.enable_guardduty ? 1 : 0

  # Explicitly enable GuardDuty detector when module is enabled
  # This is intentional - if enable_guardduty is true, we always want the detector active
  enable                       = true
  finding_publishing_frequency = var.guardduty_finding_frequency

  # enable GuardDuty S3 Protection - monitors S3 API calls (via CloudTrail)
  # Detects: data exfiltration, unauthorized access, suspicious downloads, misconfigurations
  # checks for any S3 misconfigurations, generate findings when threats are detected
  dynamic "datasources" {
    for_each = var.guardduty_datasources.s3_logs ? [1] : []
    content {
      s3_logs {
        enable = var.guardduty_datasources.s3_logs
      }
    }
  }

  # Enable GuardDuty Kubernetes Protection - comprehensive EKS security monitoring
  # Audit Logs: monitors Kubernetes API calls, detects malicious pods, privilege escalation, suspicious kubectl activities
  # Runtime Monitoring: monitors running containers for threats, malware, crypto-mining, process anomalies  
  # Addon Management: enhanced monitoring of managed EKS add-ons and their security posture
  dynamic "datasources" {
    for_each = var.guardduty_datasources.kubernetes ? [1] : []
    content {
      kubernetes {
        audit_logs {
          enable = var.guardduty_kubernetes_features.audit_logs
        }
        runtime_monitoring {
          enable = var.guardduty_kubernetes_features.runtime_monitoring
          
          dynamic "additional_configuration" {
            for_each = var.guardduty_kubernetes_features.eks_addon_management ? [1] : []
            content {
              name   = "EKS_ADDON_MANAGEMENT"
              status = "ENABLED"
            }
          }
        }
      }
    }
  }

  # Enable GuardDuty Malware Protection - scans EBS volumes when suspicious activity is detected in EC2 instances
  # Triggers automatic malware scanning of EC2 instance volumes after GuardDuty EC2 findings
  # Detects: viruses, ransomware, cryptocurrency miners, trojans in EBS-attached storage
  dynamic "datasources" {
    for_each = var.guardduty_datasources.malware_protection ? [1] : []
    content {
      malware_protection {
        scan_ec2_instance_with_findings {
          ebs_volumes {
            enable = var.guardduty_datasources.malware_protection
          }
        }
      }
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment}-guardduty-detector"
  })
}

# GuardDuty Findings CloudWatch Integration for storage, analytics, monitoring (alerts)
resource "aws_cloudwatch_log_group" "guardduty_findings" {
  count = var.enable_guardduty ? 1 : 0

  name              = "/aws/guardduty/${var.environment}"
  retention_in_days = var.security_log_retention_days
  kms_key_id        = var.enable_log_encryption ? aws_kms_key.main["security-logs"].arn : null

  tags = local.common_tags
}

# Security Hub - Single dashboard for ALL security findings
# - Automated compliance reporting
# - Correlated threat intelligence
# - Standardized security workflows
resource "aws_securityhub_account" "main" {
  count = var.enable_security_hub ? 1 : 0

  enable_default_standards = var.security_hub_enable_default_standards
  
  # Use modern finding generation engine for enhanced security findings
  control_finding_generator = "SECURITY_CONTROL"
  
  # Automatically enable new security controls when AWS adds them to standards
  auto_enable_controls     = var.security_hub_auto_enable_controls

  tags = local.common_tags
}

# Security Hub Standards Subscriptions
# Activates industry compliance frameworks (PCI DSS, CIS, NIST) for automatic security scanning
# Generates audit-ready compliance reports without manual checking
resource "aws_securityhub_standards_subscription" "standards" {
  for_each = var.enable_security_hub ? var.security_hub_standards : {}


  standards_arn = each.value.standards_arn
  
  depends_on = [aws_securityhub_account.main]
}


# AWS Config - Continuous compliance monitoring and configuration change tracking
# Records all AWS resource configurations and evaluates against compliance rules
# Enables forensic investigation and automated audit reporting
resource "aws_config_configuration_recorder" "main" {
  count = var.enable_config ? 1 : 0

  name     = "${var.environment}-config-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    #should AWS config monitor all supported aws resource types
    all_supported                 = var.config_monitor_all_resource_types
	
	#should AWS config monitor global resources that is outside any region
    include_global_resource_types = var.config_include_global_resource_types
    
	#list of resource types excluded from aws config monitoring
    dynamic "exclusion_by_resource_types" {
      for_each = length(var.config_excluded_resource_types) > 0 ? [1] : []
      content {
        resource_types = var.config_excluded_resource_types
      }
    }
    
	# set different recording settings for difference resource types for cost savings
	# Enterprise optimization: critical resources continuous, others daily/weekly
    dynamic "recording_mode_override" {
      for_each = var.config_recording_mode_overrides
      content {
        description         = recording_mode_override.value.description
        resource_types     = recording_mode_override.value.resource_types
        recording_frequency = recording_mode_override.value.recording_frequency
      }
    }
  }

  #delivery channel should exist first before aws config recorder can start. 
  depends_on = [aws_config_delivery_channel.main]
}

# Creates a pipeline that takes all the configuration data Config records and delivers it to storage/notification systems.
resource "aws_config_delivery_channel" "main" {
  count = var.enable_config ? 1 : 0

  name           = "${var.environment}-config-delivery-channel"
  s3_bucket_name = aws_s3_bucket.config[0].id
  s3_key_prefix  = "config"

  # SNS notifications send notification for each config changes occurance
  dynamic "sns_topic_arn" {
    for_each = var.config_sns_notifications ? [aws_sns_topic.config[0].arn] : []
    content {
      sns_topic_arn = sns_topic_arn.value
    }
  }
  
  #Controls how often Config delivers summary snapshots to S3
  snapshot_delivery_properties {
    delivery_frequency = var.config_delivery_frequency
  }
}

# S3 Bucket for Config
resource "aws_s3_bucket" "config" {
  count = var.enable_config ? 1 : 0

  bucket        = "${var.environment}-aws-config-${local.account_id}-${local.region}"
  
  # Can Terraform destroy S3 bucket even if it contains compliance data?
  # Enterprise safety: should be false to protect audit trail
  force_destroy = var.config_force_destroy

  tags = merge(local.common_tags, {
    Name    = "${var.environment}-aws-config-bucket"
    Purpose = "config-storage"
  })
}

resource "aws_s3_bucket_policy" "config" {
  count = var.enable_config ? 1 : 0

  bucket = aws_s3_bucket.config[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.config[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.config[0].arn}/config/AWSLogs/${local.account_id}/Config/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "AWS:SourceAccount" = local.account_id
          }
        }
      }
    ]
  })
}

# S3 Bucket Security Configuration
resource "aws_s3_bucket_versioning" "config" {
  count = var.enable_config ? 1 : 0

  bucket = aws_s3_bucket.config[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

#Sets up default encryption so that every configuration file, snapshot, and compliance report uploaded to the bucket is automatically encrypted - no manual action required.
resource "aws_s3_bucket_encryption" "config" {
  count = var.enable_config ? 1 : 0

  bucket = aws_s3_bucket.config[0].id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = var.enable_log_encryption ? aws_kms_key.main["security-logs"].arn : null
        sse_algorithm     = var.enable_log_encryption ? "aws:kms" : "AES256"
      }
    }
  }
}

# S3 Public Access Block - Enterprise data leak prevention
# Four-layer protection ensuring Config compliance data can NEVER be made public
# Prevents accidental exposure of audit trails, configuration history, and compliance reports
resource "aws_s3_bucket_public_access_block" "config" {
  count = var.enable_config ? 1 : 0

  bucket = aws_s3_bucket.config[0].id

  # Layer 1: Block creation of public ACLs on bucket and objects
  block_public_acls       = true
  # Layer 2: Block application of public bucket policies
  block_public_policy     = true
  # Layer 3: Ignore any existing public ACLs on bucket and objects
  ignore_public_acls      = true
  # Layer 4: Block cross-account public access via any method
  restrict_public_buckets = true
}

# SNS Topic creates notification broadcast for Config change or compliance violation
resource "aws_sns_topic" "config" {
  count = var.enable_config && var.config_sns_notifications ? 1 : 0

  name = "${var.environment}-config-notifications"

  kms_master_key_id = var.enable_log_encryption ? aws_kms_key.main["security-logs"].arn : null

  tags = local.common_tags
}

# Config Rules - Compliance Monitoring
resource "aws_config_config_rule" "rules" {
  for_each = var.enable_config ? var.config_rules : {}

  name = each.key

  source {
    owner             = each.value.source_owner
    source_identifier = each.value.source_identifier

    dynamic "source_detail" {
      for_each = each.value.source_details
      content {
        event_source                = source_detail.value.event_source
        message_type               = source_detail.value.message_type
        maximum_execution_frequency = source_detail.value.maximum_execution_frequency
      }
    }
  }

  # Input parameters for the rule
  dynamic "input_parameters" {
    for_each = each.value.input_parameters != null ? [each.value.input_parameters] : []
    content {
      input_parameters = input_parameters.value
    }
  }

  depends_on = [aws_config_configuration_recorder.main]

  tags = merge(local.common_tags, {
    Name = each.key
    Type = "config-rule"
  })
}

# CloudTrail - Audit Logging
resource "aws_cloudtrail" "main" {
  count = var.enable_cloudtrail ? 1 : 0

  name           = "${var.environment}-security-audit-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail[0].id
  s3_key_prefix  = "cloudtrail"

  # should the API calls be captured for the global AWS services that don't belong to a specific region
  include_global_service_events = true
  
  #is audit logging across multi region
  is_multi_region_trail        = var.cloudtrail_multi_region
  
   enable_logging               = true

  # KMS encryption
  kms_key_id = var.enable_log_encryption ? aws_kms_key.main["security-logs"].arn : null

  # CloudWatch Logs integration
  dynamic "cloud_watch_logs_group_arn" {
    for_each = var.cloudtrail_cloudwatch_logs ? [aws_cloudwatch_log_group.cloudtrail[0].arn] : []
    content {
      cloud_watch_logs_group_arn = cloud_watch_logs_group_arn.value
    }
  }

  dynamic "cloud_watch_logs_role_arn" {
    for_each = var.cloudtrail_cloudwatch_logs ? [aws_iam_role.cloudtrail_logs[0].arn] : []
    content {
      cloud_watch_logs_role_arn = cloud_watch_logs_role_arn.value
    }
  }

  # select which data events to be logged
  # management events - control plane events
  # data events -actual data access within resources
  # insight events - ML analysis of unusual activity pattern
  dynamic "event_selector" {
    for_each = var.cloudtrail_event_selectors
	content {
	  #data event - access monitoring - read/write, writeonly, all
      read_write_type           = event_selector.value.read_write_type
	  
      include_management_events = event_selector.value.include_management_events
	  
	  #select which AWS resource to log for
      dynamic "data_resource" {
        for_each = event_selector.value.data_resources
        content {
          type   = data_resource.value.type
          values = data_resource.value.values
        }
      }
    }
  }

  tags = merge(local.common_tags, {
    Name    = "${var.environment}-security-audit-trail"
    Purpose = "security-audit"
  })
}

# S3 Bucket for CloudTrail
resource "aws_s3_bucket" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket        = "${var.environment}-cloudtrail-${local.account_id}-${local.region}"
  force_destroy = var.cloudtrail_force_destroy

  tags = merge(local.common_tags, {
    Name    = "${var.environment}-cloudtrail-bucket"
    Purpose = "audit-logging"
  })
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
		# CloudTrail security validation flow:
	    # 1. Check bucket policy for GetBucketAcl permission (this statement)
	    # 2. Read actual bucket ACL (AWS default: owner full control, private)
	    # 3. Validate bucket security (CloudTrail refuses to write if bucket is public)
 	    # 4. Bucket policy provides granular security (modern approach vs basic ACL)
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:${local.partition}:cloudtrail:${local.region}:${local.account_id}:trail/${var.environment}-security-audit-trail"
          }
        }
      },
	  # After security validation passes, allow audit log writing
      # CloudTrail checks bucket policy for PutObject permission to specific path 
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/cloudtrail/AWSLogs/${local.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "AWS:SourceArn" = "arn:${local.partition}:cloudtrail:${local.region}:${local.account_id}:trail/${var.environment}-security-audit-trail"
          }
        }
      }
    ]
  })
}

# CloudWatch Log Group for CloudTrail
resource "aws_cloudwatch_log_group" "cloudtrail" {
  count = var.enable_cloudtrail && var.cloudtrail_cloudwatch_logs ? 1 : 0

  name              = "/aws/cloudtrail/${var.environment}"
  retention_in_days = var.security_log_retention_days
  kms_key_id        = var.enable_log_encryption ? aws_kms_key.main["security-logs"].arn : null

  tags = local.common_tags
}