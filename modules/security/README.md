# Enterprise Security Module

## Overview
This module provides **comprehensive enterprise security and compliance** with AWS native security services, threat detection, compliance monitoring, and automated incident response capabilities.

## Security Features

### 🔒 **Threat Detection & Response**
- **GuardDuty**: AI-powered threat detection with EKS protection
- **Security Hub**: Centralized security findings dashboard
- **Inspector**: Vulnerability assessment for containers and instances
- **Automated Response**: Lambda-based security automation

### 🛡️ **Compliance & Governance**
- **AWS Config**: Configuration compliance monitoring
- **CloudTrail**: Comprehensive audit logging
- **Multiple Standards**: SOC2, PCI-DSS, HIPAA, FedRAMP compliance
- **Custom Rules**: Configurable compliance checks

### 🔐 **Encryption & Key Management**
- **KMS Integration**: Centralized encryption key management
- **Automatic Rotation**: Key rotation for enhanced security
- **Log Encryption**: All security logs encrypted at rest
- **Multiple Key Types**: Dedicated keys per service/purpose

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                 Security Operations Center                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  GuardDuty  │  │Security Hub │  │  Inspector  │        │
│  │   Threat    │  │  Central    │  │Vulnerability│        │
│  │ Detection   │  │ Dashboard   │  │ Assessment  │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                 Compliance Monitoring                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ AWS Config  │  │ CloudTrail  │  │   Custom    │        │
│  │Configuration│  │Audit Logging│  │Config Rules │        │
│  │ Compliance  │  │             │  │             │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                 Automated Response                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ EventBridge │  │   Lambda    │  │    SNS      │        │
│  │Event Routing│  │ Automation  │  │ Alerting    │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                 Encryption Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Security    │  │EKS Secrets  │  │   Backup    │        │
│  │Logs KMS Key │  │ KMS Key     │  │ KMS Key     │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Usage
```hcl
module "security" {
  source = "../modules/security"
  
  environment = "prod"
  
  # Enable core security services
  enable_guardduty    = true
  enable_security_hub = true
  enable_config       = true
  enable_cloudtrail   = true
  enable_inspector    = true
  
  tags = {
    Project = "enterprise-platform"
    Owner   = "security-team"
  }
}
```

### Production Configuration with Advanced Features
```hcl
module "security" {
  source = "../modules/security"
  
  environment = "prod"
  
  # KMS encryption configuration
  kms_keys = {
    "security-logs" = {
      description = "Security logs encryption"
      purpose     = "security-logging"
    }
    "eks-secrets" = {
      description = "EKS secrets encryption" 
      purpose     = "eks-encryption"
    }
    "backup" = {
      description = "Backup encryption"
      purpose     = "backup-encryption"
    }
    "application-data" = {
      description = "Application data encryption"
      purpose     = "application-encryption"
    }
  }
  
  enable_log_encryption      = true
  security_log_retention_days = 180  # Extended retention for compliance
  
  # GuardDuty configuration
  enable_guardduty           = true
  guardduty_finding_frequency = "FIFTEEN_MINUTES"
  guardduty_datasources = {
    s3_logs            = true
    kubernetes         = true
    malware_protection = true
  }
  guardduty_eks_addon_management = true
  
  # Security Hub with multiple standards
  enable_security_hub               = true
  security_hub_enable_default_standards = true
  security_hub_auto_enable_controls    = true
  
  security_hub_standards = {
    "aws-foundational" = {
      standards_arn = "arn:aws:securityhub:::ruleset/finding-format/aws-foundational-security-standard"
    }
    "cis-aws-foundations" = {
      standards_arn = "arn:aws:securityhub:::ruleset/finding-format/cis-aws-foundations-benchmark"
    }
    "pci-dss" = {
      standards_arn = "arn:aws:securityhub:::ruleset/finding-format/pci-dss"
    }
    "nist" = {
      standards_arn = "arn:aws:securityhub:::ruleset/finding-format/nist-csf"
    }
  }
  
  # Custom Security Hub insights
  security_hub_custom_insights = {
    "critical-eks-findings" = {
      group_by_attribute = "ProductName"
      filters = {
        resource_type = [{
          comparison = "EQUALS"
          value     = "AwsEks*"
        }]
        severity_normalized = [{
          gte = 70
        }]
      }
    }
    
    "compliance-failures" = {
      group_by_attribute = "ComplianceStatus"
      filters = {
        compliance_status = [{
          comparison = "EQUALS"
          value     = "FAILED"
        }]
      }
    }
  }
  
  # AWS Config with comprehensive rules
  enable_config                        = true
  config_include_global_resource_types = true
  config_delivery_frequency           = "Six_Hours"
  config_sns_notifications            = true
  
  config_rules = {
    "encrypted-volumes" = {
      source_owner      = "AWS"
      source_identifier = "ENCRYPTED_VOLUMES"
    }
    "root-access-key-check" = {
      source_owner      = "AWS"
      source_identifier = "ROOT_ACCESS_KEY_CHECK"
    }
    "iam-password-policy" = {
      source_owner      = "AWS"
      source_identifier = "IAM_PASSWORD_POLICY"
    }
    "cloudtrail-enabled" = {
      source_owner      = "AWS"
      source_identifier = "CLOUD_TRAIL_ENABLED"
    }
    "eks-endpoint-no-public-access" = {
      source_owner      = "AWS"
      source_identifier = "EKS_ENDPOINT_NO_PUBLIC_ACCESS"
    }
    "eks-secrets-encrypted" = {
      source_owner      = "AWS"
      source_identifier = "EKS_SECRETS_ENCRYPTED"
    }
    "s3-bucket-public-read-prohibited" = {
      source_owner      = "AWS"
      source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
    }
    "s3-bucket-public-write-prohibited" = {
      source_owner      = "AWS"
      source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
    }
  }
  
  # CloudTrail configuration
  enable_cloudtrail         = true
  cloudtrail_multi_region   = true
  cloudtrail_cloudwatch_logs = true
  
  cloudtrail_event_selectors = [
    {
      read_write_type           = "All"
      include_management_events = true
      data_resources = [
        {
          type   = "AWS::S3::Object"
          values = ["arn:aws:s3:::*/*"]
        },
        {
          type   = "AWS::Lambda::Function"
          values = ["arn:aws:lambda:*"]
        }
      ]
    }
  ]
  
  # Security events and alerting
  enable_security_events = true
  
  security_hub_event_rules = {
    "critical-findings" = {
      description    = "Critical security findings requiring immediate attention"
      detail_types   = ["Security Hub Findings - Imported"]
      severity_range = [90, 100]
      actions_required = ["Immediate investigation required", "Follow incident response procedures"]
    }
    
    "high-severity-findings" = {
      description    = "High severity security findings"
      detail_types   = ["Security Hub Findings - Imported"]
      severity_range = [70, 89]
      actions_required = ["Review within 24 hours", "Assess for remediation"]
    }
    
    "compliance-failures" = {
      description       = "Security compliance check failures"
      detail_types      = ["Security Hub Findings - Imported"]
      compliance_status = ["FAILED"]
      actions_required  = ["Review compliance failure", "Implement remediation"]
    }
  }
  
  security_alert_subscriptions = {
    "security-team-email" = {
      protocol = "email"
      endpoint = "security-team@company.com"
      filter_policy = {
        alert_type = ["Security Hub Finding"]
        finding = {
          severity = [90, 100]  # Only critical findings
        }
      }
    }
    
    "ops-team-slack" = {
      protocol = "https"
      endpoint = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
    }
  }
  
  # Inspector v2 for vulnerability assessment
  enable_inspector       = true
  inspector_resource_types = ["ECR", "EC2", "LAMBDA"]
  
  # Security automation
  enable_security_automation = true
  # security_automation_lambda_zip = "security-automation.zip"  # Provide your Lambda code
  
  # Incident response
  enable_incident_response_role = true
  incident_response_trusted_principals = [
    "arn:aws:iam::123456789012:role/SecurityIncidentResponseTeam"
  ]
  
  # Cross-account security audit
  enable_cross_account_audit     = true
  security_audit_trusted_accounts = ["999999999999"]  # Security audit account
  security_audit_external_id     = "unique-external-id-123"
  
  # Compliance frameworks
  compliance_frameworks = ["SOC2", "PCI-DSS", "HIPAA"]
  
  tags = {
    Environment = "production"
    Project     = "enterprise-platform"
    Owner       = "security-team"
    CostCenter  = "security"
    Compliance  = "SOC2,PCI-DSS,HIPAA"
  }
}
```

### Development Environment Configuration
```hcl
module "security" {
  source = "../modules/security"
  
  environment = "dev"
  
  # Reduced security services for cost optimization
  enable_guardduty    = true
  enable_security_hub = true
  enable_config       = false  # Disabled for dev
  enable_cloudtrail   = true
  enable_inspector    = false  # Disabled for dev
  
  # Cost-optimized settings
  guardduty_finding_frequency = "SIX_HOURS"  # Less frequent for cost savings
  security_log_retention_days = 7           # Shorter retention
  
  security_hub_standards = {
    "aws-foundational" = {
      standards_arn = "arn:aws:securityhub:::ruleset/finding-format/aws-foundational-security-standard"
    }
  }
  
  # Basic alerting only
  enable_security_events = false
  
  tags = {
    Environment = "development"
    Project     = "enterprise-platform"
    Owner       = "dev-team"
  }
}
```

## Security Best Practices

### 1. **Multi-Layered Security**
```hcl
# Enable all core security services
enable_guardduty    = true  # Threat detection
enable_security_hub = true  # Centralized findings
enable_config       = true  # Compliance monitoring
enable_cloudtrail   = true  # Audit logging
enable_inspector    = true  # Vulnerability assessment
```

### 2. **Encryption Everywhere**
```hcl
# Enable encryption for all security logs
enable_log_encryption = true

# Create dedicated KMS keys per service
kms_keys = {
  "security-logs" = { purpose = "security-logging" }
  "eks-secrets"   = { purpose = "eks-encryption" }
  "backup"        = { purpose = "backup-encryption" }
}
```

### 3. **Comprehensive Monitoring**
```hcl
# Enable all GuardDuty data sources
guardduty_datasources = {
  s3_logs            = true
  kubernetes         = true  # Essential for EKS
  malware_protection = true
}
```

### 4. **Automated Response**
```hcl
# Set up automated security response
enable_security_automation = true
enable_security_events     = true

# Configure alerting based on severity
security_hub_event_rules = {
  "critical-findings" = {
    severity_range = [90, 100]
    actions_required = ["Immediate investigation"]
  }
}
```

## Compliance Frameworks

### SOC 2 Alignment
- ✅ **Security**: GuardDuty, Security Hub, Inspector
- ✅ **Availability**: Multi-region CloudTrail, redundant logging
- ✅ **Processing Integrity**: Config rules, compliance monitoring
- ✅ **Confidentiality**: KMS encryption, access controls
- ✅ **Privacy**: Data classification, access logging

### PCI DSS Alignment
- ✅ **Network Security**: GuardDuty network monitoring
- ✅ **Access Control**: IAM integration, audit trails
- ✅ **Encryption**: KMS keys, encrypted storage
- ✅ **Monitoring**: Real-time security monitoring
- ✅ **Testing**: Vulnerability assessments with Inspector

### HIPAA Alignment
- ✅ **Administrative**: Security policies and procedures
- ✅ **Physical**: Cloud infrastructure security
- ✅ **Technical**: Encryption, access controls, audit logs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name | `string` | n/a | yes |
| enable_guardduty | Enable GuardDuty | `bool` | `true` | no |
| enable_security_hub | Enable Security Hub | `bool` | `true` | no |
| enable_config | Enable AWS Config | `bool` | `true` | no |
| enable_cloudtrail | Enable CloudTrail | `bool` | `true` | no |
| enable_inspector | Enable Inspector | `bool` | `true` | no |
| kms_keys | KMS keys configuration | `map(object)` | `{}` | no |
| compliance_frameworks | Compliance frameworks | `list(string)` | `["SOC2", "PCI-DSS"]` | no |

## Outputs

| Name | Description |
|------|-------------|
| kms_key_arns | KMS key ARNs for encryption |
| guardduty_detector | GuardDuty detector information |
| security_hub_account | Security Hub configuration |
| config_rules | AWS Config rules created |
| cloudtrail | CloudTrail configuration |
| security_alerts_topic | SNS topic for alerts |

## Cost Optimization

### 1. **Environment-Specific Configuration**
```hcl
# Production: Full security suite
enable_guardduty = true
enable_inspector = true
security_log_retention_days = 90

# Development: Reduced services
enable_inspector = false  # Save ~$0.09 per container image scan
security_log_retention_days = 7  # Reduce log storage costs
```

### 2. **GuardDuty Optimization**
```hcl
# Adjust finding frequency based on needs
guardduty_finding_frequency = "SIX_HOURS"  # vs "FIFTEEN_MINUTES"

# Selective data sources for development
guardduty_datasources = {
  s3_logs            = true
  kubernetes         = true   # Always enable for EKS
  malware_protection = false  # Disable in dev
}
```

### 3. **Log Retention Management**
```hcl
# Adjust retention based on compliance requirements
security_log_retention_days = 90   # Production
security_log_retention_days = 30   # Staging
security_log_retention_days = 7    # Development
```

## Troubleshooting

### Issue: GuardDuty not detecting EKS threats
**Solution**: Ensure EKS audit logs and runtime monitoring are enabled
```bash
# Check GuardDuty detector features
aws guardduty list-detectors
aws guardduty get-detector --detector-id <id>
```

### Issue: Security Hub findings not appearing
**Solution**: Verify standards are enabled and services are integrated
```bash
# Check Security Hub status
aws securityhub get-enabled-standards
aws securityhub describe-hub
```

### Issue: Config rules showing non-compliant resources
**Solution**: Review rule parameters and resource configurations
```bash
# Check Config rule status
aws configservice describe-config-rules
aws configservice get-compliance-details-by-config-rule --config-rule-name <name>
```

### Issue: High costs from security services
**Solution**: Optimize configurations for your environment
- Reduce GuardDuty finding frequency in non-production
- Disable expensive features like malware protection in development
- Adjust log retention periods based on compliance needs

## Integration with Other Modules

### VPC Module Integration
```hcl
# Use security module KMS keys in VPC module
module "vpc" {
  source = "../modules/vpc"
  
  enable_flow_logs = true
  flow_log_kms_key_id = module.security.kms_key_arns["security-logs"]
}
```

### EKS Module Integration
```hcl
# Use security module KMS keys for EKS
module "eks" {
  source = "../modules/eks"
  
  enable_cluster_encryption = true
  kms_key_id = module.security.kms_key_arns["eks-secrets"]
}
```

## References
- [AWS Security Hub Best Practices](https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-best-practices.html)
- [GuardDuty EKS Protection](https://docs.aws.amazon.com/guardduty/latest/ug/kubernetes-protection.html)
- [AWS Config Compliance](https://docs.aws.amazon.com/config/latest/developerguide/evaluate-config.html)