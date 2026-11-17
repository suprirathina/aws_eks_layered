# Enterprise IAM Module

## Overview
This module provides **centralized Identity and Access Management (IAM)** with AWS Identity Center integration, predefined permission sets, and enterprise security best practices for multi-account AWS environments.

## Security Features

### 🔒 **Identity Center Integration**
- **Centralized Authentication**: Single sign-on across all AWS accounts
- **Predefined Permission Sets**: Industry-standard access patterns
- **Least Privilege Access**: Minimal permissions by design
- **Session Management**: Configurable session durations and MFA requirements

### 🛡️ **Access Control**
- **Role-Based Access Control (RBAC)**: Permission sets for different roles
- **Cross-Account Access**: Secure multi-account trust relationships
- **Break Glass Access**: Emergency access procedures with audit trails
- **Service Account Integration**: IRSA support for Kubernetes workloads

### 👥 **User Management**
- **Group-Based Assignments**: Users inherit permissions through groups
- **Temporary Access**: Time-limited elevated permissions
- **Audit Trail**: Complete access history and policy changes
- **Compliance Ready**: SOC2, PCI-DSS, HIPAA alignment

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                AWS Identity Center                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   EKS-Admin │  │EKS-Developer│  │EKS-ReadOnly │        │
│  │Permission   │  │Permission   │  │Permission   │        │
│  │Set          │  │Set          │  │Set          │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                Account Assignments                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │Development  │  │Staging      │  │Production   │        │
│  │Account      │  │Account      │  │Account      │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                   IRSA Integration                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │Service      │  │Application  │  │Platform     │        │
│  │Accounts     │  │Roles        │  │Roles        │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Usage
```hcl
module "iam" {
  source = "../modules/iam"
  
  environment = "prod"
  identity_center_instance_arn = "arn:aws:sso:::instance/ssoins-xxxxxxxxx"
  
  # Enable default permission sets
  enable_default_permission_sets = true
  
  tags = {
    Project = "enterprise-platform"
    Owner   = "platform-team"
  }
}
```

### Production Configuration with Custom Permission Sets
```hcl
module "iam" {
  source = "../modules/iam"
  
  environment = "prod"
  identity_center_instance_arn = "arn:aws:sso:::instance/ssoins-xxxxxxxxx"
  
  # Enable default permission sets
  enable_default_permission_sets = true
  default_permission_sets_config = {
    create_readonly_access  = true
    create_poweruser_access = true
    create_admin_access     = true
    create_billing_access   = true
    create_security_audit   = true
    create_eks_admin       = true
    create_eks_developer   = true
    create_eks_viewer      = true
  }
  
  # Custom permission sets for specific needs
  permission_sets = {
    "DataScientist" = {
      description      = "Data scientist access with ML and analytics permissions"
      session_duration = "PT8H"
      access_level     = "DataScience"
      
      aws_managed_policies = [
        "arn:aws:iam::aws:policy/job-function/DataScientist"
      ]
      
      inline_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "sagemaker:*",
              "s3:GetObject",
              "s3:PutObject"
            ]
            Resource = [
              "arn:aws:s3:::ml-datasets/*",
              "arn:aws:s3:::ml-models/*"
            ]
          }
        ]
      })
      
      account_assignments = [
        {
          principal_id   = "90670000000-aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"  # User ID
          principal_type = "USER"
          target_id      = "123456789012"  # Account ID
          target_type    = "AWS_ACCOUNT"
        }
      ]
    }
  }
  
  # Custom policies for fine-grained access
  custom_policies = {
    "EKSNamespaceAccess" = {
      description = "Namespace-scoped access for developers"
      policy_document = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = ["eks:AccessKubernetesApi"]
            Resource = "*"
            Condition = {
              StringEquals = {
                "kubernetes.io/resource/namespace" = ["dev-team-a", "dev-team-b"]
              }
            }
          }
        ]
      })
    }
  }
  
  # EKS-specific roles for service accounts
  eks_roles = {
    "external-secrets-operator" = {
      purpose = "External Secrets Operator IRSA role"
      principal = {
        Federated = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/XXXXX"
      }
      conditions = {
        StringEquals = {
          "oidc.eks.us-east-1.amazonaws.com/id/XXXXX:sub" = "system:serviceaccount:external-secrets-system:external-secrets"
          "oidc.eks.us-east-1.amazonaws.com/id/XXXXX:aud" = "sts.amazonaws.com"
        }
      }
      managed_policies = [
        "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
      ]
    }
  }
  
  # Security configuration
  enable_password_policy = true
  password_policy = {
    minimum_length     = 16
    require_lowercase  = true
    require_numbers    = true
    require_uppercase  = true
    require_symbols    = true
    max_age           = 90
    reuse_prevention  = 12
  }
  
  enable_access_analyzer = true
  enable_break_glass_role = true
  break_glass_trusted_principals = [
    "arn:aws:iam::123456789012:role/EmergencyAccessRole"
  ]
  
  compliance_frameworks = ["SOC2", "PCI-DSS"]
  
  tags = {
    Environment = "production"
    Project     = "enterprise-platform"
    Owner       = "platform-team"
    CostCenter  = "engineering"
    Compliance  = "SOC2,PCI-DSS"
  }
}
```

### Multi-Account Organization Setup
```hcl
module "iam" {
  source = "../modules/iam"
  
  environment = "prod"
  identity_center_instance_arn = "arn:aws:sso:::instance/ssoins-xxxxxxxxx"
  
  # Multi-account configuration
  organization_config = {
    management_account_id   = "111111111111"
    central_logging_account = "222222222222"
    security_account       = "333333333333"
    
    organizational_units = {
      "Development" = {
        name = "Development"
        policy_arns = [
          "arn:aws:organizations::aws:policy/service_control_policy/p-FullAWSAccess"
        ]
      }
      "Production" = {
        name = "Production"
        policy_arns = [
          "arn:aws:organizations::aws:policy/service_control_policy/p-RestrictedAWSAccess"
        ]
      }
    }
  }
  
  # Cross-account roles for centralized management
  cross_account_roles = {
    "central-logging-access" = {
      purpose = "Cross-account access for central logging"
      trusted_accounts = ["222222222222"]  # Central logging account
      managed_policies = [
        "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
      ]
    }
    
    "security-audit-access" = {
      purpose = "Cross-account security auditing"
      trusted_accounts = ["333333333333"]  # Security account
      managed_policies = [
        "arn:aws:iam::aws:policy/SecurityAudit"
      ]
    }
  }
}
```

## Default Permission Sets

The module includes enterprise-standard permission sets:

### **EKS-AdminAccess**
- **Purpose**: Full EKS cluster administration
- **Session Duration**: 4 hours (security)
- **Features**: Full administrative access with MFA requirements for destructive actions
- **Use Case**: Platform team, Site Reliability Engineers

### **EKS-PowerUserAccess**
- **Purpose**: Development and deployment activities
- **Session Duration**: 8 hours
- **Features**: EKS management, ECR access, limited IAM permissions
- **Use Case**: DevOps engineers, Senior developers

### **EKS-DeveloperAccess**
- **Purpose**: Application development and deployment
- **Session Duration**: 8 hours
- **Features**: Namespace-scoped access, ECR push to dev repos, secrets access
- **Use Case**: Application developers

### **EKS-ReadOnlyAccess**
- **Purpose**: Auditing and compliance monitoring
- **Session Duration**: 4 hours
- **Features**: Read-only access across EKS and supporting services
- **Use Case**: Auditors, Compliance team, Reporting

### **EKS-SecurityAuditor**
- **Purpose**: Security assessment and compliance
- **Session Duration**: 8 hours
- **Features**: Enhanced security tool access, audit capabilities
- **Use Case**: Security team, Compliance officers

### **BillingAccess** (Optional)
- **Purpose**: Cost management and billing
- **Session Duration**: 4 hours
- **Features**: Full billing access, cost optimization tools
- **Use Case**: Finance team, Cost management

## IRSA Integration

### Creating Service Account Roles
```hcl
# Example: Application-specific IRSA role
resource "aws_iam_role" "my_app" {
  name = "my-cluster-my-app"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = module.iam.oidc_provider_arns["eks"]
        }
        Condition = {
          StringEquals = {
            "oidc.eks.region.amazonaws.com/id/XXXXX:sub" = "system:serviceaccount:my-namespace:my-service-account"
            "oidc.eks.region.amazonaws.com/id/XXXXX:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}
```

### Kubernetes Service Account
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-service-account
  namespace: my-namespace
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/my-cluster-my-app
```

## Security Best Practices

### 1. **Least Privilege Access**
```hcl
# Example: Restrict developer access to specific resources
inline_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:PutObject"]
      Resource = ["arn:aws:s3:::dev-bucket/*"]
    },
    {
      Effect = "Deny"
      Action = "*"
      Resource = "*prod*"
    }
  ]
})
```

### 2. **MFA Requirements**
```hcl
# Require MFA for administrative actions
inline_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Effect = "Deny"
      Action = ["eks:DeleteCluster", "iam:DeleteRole"]
      Resource = "*"
      Condition = {
        Bool = {
          "aws:MultiFactorAuthPresent" = "false"
        }
      }
    }
  ]
})
```

### 3. **Session Duration Limits**
```hcl
# Limit session duration for high-privilege roles
permission_sets = {
  "AdminAccess" = {
    session_duration = "PT1H"  # 1 hour maximum
    # ... other configuration
  }
}
```

### 4. **Break Glass Procedures**
```hcl
# Emergency access with strict conditions
enable_break_glass_role = true
break_glass_trusted_principals = [
  "arn:aws:iam::account:user/emergency-admin"
]
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name | `string` | n/a | yes |
| identity_center_instance_arn | Identity Center instance ARN | `string` | n/a | yes |
| permission_sets | Custom permission sets | `map(object)` | `{}` | no |
| enable_default_permission_sets | Enable default permission sets | `bool` | `true` | no |
| custom_policies | Custom IAM policies | `map(object)` | `{}` | no |
| enable_password_policy | Enable password policy | `bool` | `true` | no |
| enable_access_analyzer | Enable Access Analyzer | `bool` | `true` | no |
| enable_break_glass_role | Enable break glass role | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| permission_sets | Created permission sets |
| permission_set_arns | Permission set ARNs |
| custom_policies | Created custom policies |
| eks_roles | EKS-related IAM roles |
| break_glass_role | Break glass role information |

## Compliance

### SOC 2 Alignment
- ✅ **Access Controls**: Role-based access with least privilege
- ✅ **Monitoring**: IAM Access Analyzer and audit trails
- ✅ **Security**: MFA requirements and session controls

### PCI DSS Alignment
- ✅ **Access Restriction**: Multi-layered access controls
- ✅ **Authentication**: Strong authentication requirements
- ✅ **Monitoring**: Comprehensive access logging

### HIPAA Alignment
- ✅ **Access Control**: Unique user identification and access management
- ✅ **Audit**: Complete access audit trails
- ✅ **Security**: Encryption and secure access patterns

## Troubleshooting

### Issue: Permission Set Not Working
**Solution**: Verify account assignments and policy attachments
```bash
# Check permission set status
aws sso-admin list-permission-sets --instance-arn <arn>

# Verify account assignments
aws sso-admin list-account-assignments --instance-arn <arn> --permission-set-arn <arn>
```

### Issue: IRSA Role Assumption Failed
**Solution**: Verify OIDC provider and trust relationships
```bash
# Check OIDC provider
aws iam list-open-id-connect-providers

# Test role assumption
aws sts assume-role-with-web-identity --role-arn <role-arn> --role-session-name test --web-identity-token <token>
```

### Issue: Access Denied for Cross-Account
**Solution**: Verify trust relationships and SCPs
```bash
# Check role trust policy
aws iam get-role --role-name <role-name>

# Verify SCP restrictions
aws organizations list-policies-for-target --target-id <account-id> --filter SERVICE_CONTROL_POLICY
```

## References
- [AWS Identity Center Best Practices](https://docs.aws.amazon.com/singlesignon/latest/userguide/best-practices.html)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)