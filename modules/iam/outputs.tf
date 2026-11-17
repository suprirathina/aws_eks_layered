# IAM Module Outputs - Identity and Access Management Information

# Identity Center Permission Sets
output "permission_sets" {
  description = "Map of created Identity Center permission sets"
  value = {
    for k, v in aws_ssoadmin_permission_set.this : k => {
      arn              = v.arn
      name             = v.name
      description      = v.description
      session_duration = v.session_duration
      created_date     = v.created_date
    }
  }
}

output "permission_set_arns" {
  description = "Map of permission set names to ARNs"
  value = {
    for k, v in aws_ssoadmin_permission_set.this : k => v.arn
  }
}

# Identity Center Account Assignments
output "account_assignments" {
  description = "Map of account assignments created"
  value = {
    for k, v in aws_ssoadmin_account_assignment.this : k => {
      permission_set_arn = v.permission_set_arn
      principal_id       = v.principal_id
      principal_type     = v.principal_type
      target_id          = v.target_id
      target_type        = v.target_type
    }
  }
}

# Custom IAM Policies
output "custom_policies" {
  description = "Map of created custom IAM policies"
  value = {
    for k, v in aws_iam_policy.custom_policies : k => {
      arn         = v.arn
      name        = v.name
      description = v.description
      path        = v.path
      policy_id   = v.policy_id
    }
  }
}

output "custom_policy_arns" {
  description = "Map of custom policy names to ARNs"
  value = {
    for k, v in aws_iam_policy.custom_policies : k => v.arn
  }
}

# EKS IAM Roles
output "eks_roles" {
  description = "Map of created EKS-related IAM roles"
  value = {
    for k, v in aws_iam_role.eks_roles : k => {
      arn                   = v.arn
      name                  = v.name
      path                  = v.path
      unique_id             = v.unique_id
      max_session_duration  = v.max_session_duration
      create_date          = v.create_date
    }
  }
}

output "eks_role_arns" {
  description = "Map of EKS role names to ARNs"
  value = {
    for k, v in aws_iam_role.eks_roles : k => v.arn
  }
}

# Cross-Account IAM Roles
output "cross_account_roles" {
  description = "Map of created cross-account IAM roles"
  value = {
    for k, v in aws_iam_role.cross_account_roles : k => {
      arn                   = v.arn
      name                  = v.name
      path                  = v.path
      unique_id             = v.unique_id
      max_session_duration  = v.max_session_duration
      create_date          = v.create_date
    }
  }
}

output "cross_account_role_arns" {
  description = "Map of cross-account role names to ARNs"
  value = {
    for k, v in aws_iam_role.cross_account_roles : k => v.arn
  }
}

# Service-Linked Roles
output "service_linked_roles" {
  description = "Map of created service-linked roles"
  value = {
    for k, v in aws_iam_service_linked_role.this : k => {
      arn           = v.arn
      name          = v.name
      path          = v.path
      unique_id     = v.unique_id
      create_date   = v.create_date
    }
  }
}

# OIDC Identity Providers
output "oidc_providers" {
  description = "Map of created OIDC identity providers"
  value = {
    for k, v in aws_iam_openid_connect_provider.this : k => {
      arn             = v.arn
      url             = v.url
      client_id_list  = v.client_id_list
      thumbprint_list = v.thumbprint_list
    }
  }
}

output "oidc_provider_arns" {
  description = "Map of OIDC provider names to ARNs"
  value = {
    for k, v in aws_iam_openid_connect_provider.this : k => v.arn
  }
}

# Security Configuration
output "password_policy" {
  description = "IAM account password policy configuration"
  value = var.enable_password_policy ? {
    minimum_password_length        = aws_iam_account_password_policy.this[0].minimum_password_length
    require_lowercase_characters   = aws_iam_account_password_policy.this[0].require_lowercase_characters
    require_numbers               = aws_iam_account_password_policy.this[0].require_numbers
    require_uppercase_characters   = aws_iam_account_password_policy.this[0].require_uppercase_characters
    require_symbols               = aws_iam_account_password_policy.this[0].require_symbols
    allow_users_to_change_password = aws_iam_account_password_policy.this[0].allow_users_to_change_password
    hard_expiry                   = aws_iam_account_password_policy.this[0].hard_expiry
    max_password_age              = aws_iam_account_password_policy.this[0].max_password_age
    password_reuse_prevention     = aws_iam_account_password_policy.this[0].password_reuse_prevention
  } : null
}

output "access_analyzer" {
  description = "IAM Access Analyzer configuration"
  value = var.enable_access_analyzer ? {
    arn           = aws_accessanalyzer_analyzer.this[0].arn
    analyzer_name = aws_accessanalyzer_analyzer.this[0].analyzer_name
    type         = aws_accessanalyzer_analyzer.this[0].type
  } : null
}

# Break Glass Role
output "break_glass_role" {
  description = "Emergency break glass role configuration"
  value = var.enable_break_glass_role ? {
    arn                   = aws_iam_role.break_glass[0].arn
    name                  = aws_iam_role.break_glass[0].name
    path                  = aws_iam_role.break_glass[0].path
    max_session_duration  = aws_iam_role.break_glass[0].max_session_duration
  } : null
}

# Default Permission Sets Information
output "default_permission_sets_created" {
  description = "List of default permission sets that were created"
  value = var.enable_default_permission_sets ? [
    for k, v in local.default_permission_sets : k
    if v != null
  ] : []
}

# IRSA Helper Information
output "irsa_role_templates" {
  description = "Helper templates for creating IRSA roles"
  value = {
    trust_policy_template = {
      Version = "2012-10-17"
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Federated = "OIDC_PROVIDER_ARN"  # Replace with actual OIDC provider ARN
          }
          Condition = {
            StringEquals = {
              "OIDC_ISSUER_URL:sub" = "system:serviceaccount:NAMESPACE:SERVICE_ACCOUNT"
              "OIDC_ISSUER_URL:aud" = "sts.amazonaws.com"
            }
          }
        }
      ]
    }
    
    common_service_accounts = {
      aws_load_balancer_controller = {
        namespace       = "kube-system"
        service_account = "aws-load-balancer-controller"
      }
      cluster_autoscaler = {
        namespace       = "kube-system"
        service_account = "cluster-autoscaler"
      }
      external_secrets = {
        namespace       = "external-secrets-system"
        service_account = "external-secrets"
      }
      ebs_csi_driver = {
        namespace       = "kube-system"
        service_account = "ebs-csi-controller-sa"
      }
    }
  }
}

# Identity Center Integration Helper
output "identity_center_integration" {
  description = "Helper information for Identity Center integration"
  value = {
    instance_arn = var.identity_center_instance_arn
    
    # Permission set summaries for documentation
    permission_set_summary = {
      for k, v in aws_ssoadmin_permission_set.this : k => {
        description      = v.description
        session_duration = v.session_duration
        access_level     = try(local.all_permission_sets[k].access_level, "Unknown")
      }
    }
    
    # AWS CLI commands for common operations
    aws_cli_examples = {
      list_permission_sets = "aws sso-admin list-permission-sets --instance-arn ${var.identity_center_instance_arn}"
      list_accounts       = "aws organizations list-accounts"
      configure_sso       = "aws configure sso"
    }
  }
}

# Compliance and Security Information
output "compliance_alignment" {
  description = "Information about compliance framework alignment"
  value = {
    frameworks_configured = var.compliance_frameworks
    
    security_features = {
      password_policy_enabled    = var.enable_password_policy
      access_analyzer_enabled    = var.enable_access_analyzer
      break_glass_role_enabled   = var.enable_break_glass_role
      cloudtrail_integration     = var.enable_cloudtrail_integration
      config_integration         = var.enable_config_integration
    }
    
    best_practices_implemented = [
      "Least Privilege Access",
      "Separation of Duties",
      "Multi-Factor Authentication Requirements",
      "Session Duration Limits",
      "Audit Trail Implementation",
      "Emergency Access Procedures"
    ]
  }
}

# Multi-Account Organization Support
output "organization_configuration" {
  description = "Multi-account organization configuration"
  value = var.organization_config
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

# Tags Applied
output "common_tags" {
  description = "Common tags applied to all IAM resources"
  value = local.common_tags
}