# Security Module Outputs - Security and Compliance Information

# KMS Keys
output "kms_keys" {
  description = "Map of created KMS keys"
  value = {
    for k, v in aws_kms_key.main : k => {
      arn       = v.arn
      key_id    = v.key_id
      key_usage = v.key_usage
      key_spec  = v.key_spec
    }
  }
}

output "kms_key_arns" {
  description = "Map of KMS key names to ARNs"
  value = {
    for k, v in aws_kms_key.main : k => v.arn
  }
}

output "kms_aliases" {
  description = "Map of KMS aliases"
  value = {
    for k, v in aws_kms_alias.main : k => {
      arn           = v.arn
      name          = v.name
      target_key_id = v.target_key_id
    }
  }
}

# GuardDuty
output "guardduty_detector" {
  description = "GuardDuty detector information"
  value = var.enable_guardduty ? {
    id                           = aws_guardduty_detector.main[0].id
    arn                         = aws_guardduty_detector.main[0].arn
    account_id                  = aws_guardduty_detector.main[0].account_id
    finding_publishing_frequency = aws_guardduty_detector.main[0].finding_publishing_frequency
  } : null
}

output "guardduty_detector_features" {
  description = "GuardDuty detector features enabled"
  value = var.enable_guardduty && var.guardduty_datasources.kubernetes ? {
    eks_audit_logs        = aws_guardduty_detector_feature.eks_audit_logs[0].status
    eks_runtime_monitoring = aws_guardduty_detector_feature.eks_runtime_monitoring[0].status
  } : {}
}

# Security Hub
output "security_hub_account" {
  description = "Security Hub account information"
  value = var.enable_security_hub ? {
    id                           = aws_securityhub_account.main[0].id
    arn                         = aws_securityhub_account.main[0].arn
    enable_default_standards    = aws_securityhub_account.main[0].enable_default_standards
    control_finding_generator   = aws_securityhub_account.main[0].control_finding_generator
  } : null
}

output "security_hub_standards" {
  description = "Security Hub standards subscriptions"
  value = var.enable_security_hub ? {
    for k, v in aws_securityhub_standards_subscription.standards : k => {
      standards_arn           = v.standards_arn
      standards_status       = v.standards_status
      standards_status_reason = v.standards_status_reason
    }
  } : {}
}

output "security_hub_insights" {
  description = "Security Hub custom insights"
  value = var.enable_security_hub ? {
    for k, v in aws_securityhub_insight.custom_insights : k => {
      insight_arn        = v.insight_arn
      name              = v.name
      group_by_attribute = v.group_by_attribute
    }
  } : {}
}

output "security_hub_action_targets" {
  description = "Security Hub action targets"
  value = var.enable_security_hub ? {
    for k, v in aws_securityhub_action_target.remediation : k => {
      arn         = v.arn
      identifier  = v.identifier
      description = v.description
    }
  } : {}
}

# AWS Config
output "config_recorder" {
  description = "AWS Config recorder information"
  value = var.enable_config ? {
    name     = aws_config_configuration_recorder.main[0].name
    role_arn = aws_config_configuration_recorder.main[0].role_arn
  } : null
}

output "config_delivery_channel" {
  description = "AWS Config delivery channel information"
  value = var.enable_config ? {
    name           = aws_config_delivery_channel.main[0].name
    s3_bucket_name = aws_config_delivery_channel.main[0].s3_bucket_name
  } : null
}

output "config_rules" {
  description = "AWS Config rules created"
  value = var.enable_config ? {
    for k, v in aws_config_config_rule.rules : k => {
      name                = v.name
      arn                 = v.arn
      rule_id             = v.rule_id
      source_identifier   = v.source[0].source_identifier
    }
  } : {}
}

output "config_bucket" {
  description = "AWS Config S3 bucket information"
  value = var.enable_config ? {
    id   = aws_s3_bucket.config[0].id
    arn  = aws_s3_bucket.config[0].arn
    region = aws_s3_bucket.config[0].region
  } : null
}

# CloudTrail
output "cloudtrail" {
  description = "CloudTrail information"
  value = var.enable_cloudtrail ? {
    arn                     = aws_cloudtrail.main[0].arn
    name                    = aws_cloudtrail.main[0].name
    s3_bucket_name         = aws_cloudtrail.main[0].s3_bucket_name
    home_region            = aws_cloudtrail.main[0].home_region
    is_multi_region_trail  = aws_cloudtrail.main[0].is_multi_region_trail
  } : null
}

output "cloudtrail_bucket" {
  description = "CloudTrail S3 bucket information"
  value = var.enable_cloudtrail ? {
    id   = aws_s3_bucket.cloudtrail[0].id
    arn  = aws_s3_bucket.cloudtrail[0].arn
    region = aws_s3_bucket.cloudtrail[0].region
  } : null
}

output "cloudtrail_log_group" {
  description = "CloudTrail CloudWatch log group"
  value = var.enable_cloudtrail && var.cloudtrail_cloudwatch_logs ? {
    name = aws_cloudwatch_log_group.cloudtrail[0].name
    arn  = aws_cloudwatch_log_group.cloudtrail[0].arn
  } : null
}

# Security Events
output "security_alerts_topic" {
  description = "Security alerts SNS topic"
  value = var.enable_security_events ? {
    arn  = aws_sns_topic.security_alerts[0].arn
    name = aws_sns_topic.security_alerts[0].name
  } : null
}

output "security_event_rules" {
  description = "Security EventBridge rules"
  value = var.enable_security_hub && var.enable_security_events ? {
    for k, v in aws_cloudwatch_event_rule.security_hub_findings : k => {
      arn   = v.arn
      name  = v.name
      state = v.state
    }
  } : {}
}

# Security Automation
output "security_automation_lambda" {
  description = "Security automation Lambda function"
  value = var.enable_security_automation ? {
    function_name = aws_lambda_function.security_automation[0].function_name
    function_arn  = aws_lambda_function.security_automation[0].arn
    role         = aws_lambda_function.security_automation[0].role
  } : null
}

# IAM Roles
output "security_iam_roles" {
  description = "Security-related IAM roles"
  value = {
    config_role = var.enable_config ? {
      name = aws_iam_role.config[0].name
      arn  = aws_iam_role.config[0].arn
    } : null
    
    cloudtrail_logs_role = var.enable_cloudtrail && var.cloudtrail_cloudwatch_logs ? {
      name = aws_iam_role.cloudtrail_logs[0].name
      arn  = aws_iam_role.cloudtrail_logs[0].arn
    } : null
    
    security_lambda_role = var.enable_security_automation ? {
      name = aws_iam_role.security_lambda[0].name
      arn  = aws_iam_role.security_lambda[0].arn
    } : null
    
    incident_response_role = var.enable_incident_response_role ? {
      name = aws_iam_role.incident_response[0].name
      arn  = aws_iam_role.incident_response[0].arn
    } : null
    
    cross_account_audit_role = var.enable_cross_account_audit ? {
      name = aws_iam_role.cross_account_audit[0].name
      arn  = aws_iam_role.cross_account_audit[0].arn
    } : null
  }
}

# Inspector
output "inspector_enabler" {
  description = "Inspector enabler information"
  value = var.enable_inspector ? {
    account_ids    = aws_inspector2_enabler.inspector[0].account_ids
    resource_types = aws_inspector2_enabler.inspector[0].resource_types
  } : null
}

# Log Groups
output "security_log_groups" {
  description = "Security-related CloudWatch log groups"
  value = {
    guardduty_findings = var.enable_guardduty ? {
      name = aws_cloudwatch_log_group.guardduty_findings[0].name
      arn  = aws_cloudwatch_log_group.guardduty_findings[0].arn
    } : null
    
    cloudtrail = var.enable_cloudtrail && var.cloudtrail_cloudwatch_logs ? {
      name = aws_cloudwatch_log_group.cloudtrail[0].name
      arn  = aws_cloudwatch_log_group.cloudtrail[0].arn
    } : null
  }
}

# Compliance Information
output "compliance_status" {
  description = "Compliance framework alignment information"
  value = {
    frameworks_enabled = var.compliance_frameworks
    
    services_enabled = {
      guardduty    = var.enable_guardduty
      security_hub = var.enable_security_hub
      config       = var.enable_config
      cloudtrail   = var.enable_cloudtrail
      inspector    = var.enable_inspector
    }
    
    encryption_enabled = var.enable_log_encryption
    
    log_retention_days = var.security_log_retention_days
    
    standards_enabled = var.enable_security_hub ? [
      for k, v in var.security_hub_standards : k
    ] : []
  }
}

# Security Recommendations
output "security_recommendations" {
  description = "Security configuration recommendations"
  value = {
    improve_security = [
      var.enable_guardduty ? null : "Enable GuardDuty for threat detection",
      var.enable_security_hub ? null : "Enable Security Hub for centralized findings",
      var.enable_config ? null : "Enable Config for compliance monitoring",
      var.enable_cloudtrail ? null : "Enable CloudTrail for audit logging",
      var.enable_log_encryption ? null : "Enable KMS encryption for logs",
      var.enable_inspector ? null : "Enable Inspector for vulnerability assessment"
    ]
    
    cost_optimization = [
      var.guardduty_finding_frequency == "FIFTEEN_MINUTES" ? "Consider reducing GuardDuty finding frequency for cost savings" : null,
      var.security_log_retention_days > 90 ? "Consider reducing log retention for development environments" : null
    ]
    
    operational_excellence = [
      var.enable_security_events ? null : "Enable security event notifications",
      var.enable_security_automation ? null : "Consider enabling security automation",
      length(var.security_alert_subscriptions) > 0 ? null : "Configure security alert subscriptions"
    ]
  }
}

# Account Information
output "account_info" {
  description = "Current AWS account information"
  value = {
    account_id = local.account_id
    region     = local.region
    partition  = local.partition
  }
}

# Resource ARNs for Integration
output "integration_arns" {
  description = "ARNs for integration with other modules"
  value = {
    security_logs_kms_key = aws_kms_key.main["security-logs"].arn
    eks_secrets_kms_key  = aws_kms_key.main["eks-secrets"].arn
    backup_kms_key       = aws_kms_key.main["backup"].arn
    
    security_alerts_topic = var.enable_security_events ? aws_sns_topic.security_alerts[0].arn : null
    
    config_bucket_arn    = var.enable_config ? aws_s3_bucket.config[0].arn : null
    cloudtrail_bucket_arn = var.enable_cloudtrail ? aws_s3_bucket.cloudtrail[0].arn : null
    
    guardduty_detector_id = var.enable_guardduty ? aws_guardduty_detector.main[0].id : null
    
    incident_response_role_arn = var.enable_incident_response_role ? aws_iam_role.incident_response[0].arn : null
  }
}

# Tags Applied
output "common_tags" {
  description = "Common tags applied to all security resources"
  value = local.common_tags
}