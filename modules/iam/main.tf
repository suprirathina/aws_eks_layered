# Enterprise IAM Module with Identity Center Integration
# Centralized IAM management with least privilege access patterns

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
      Module      = "iam"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )

  # Account information
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  partition  = data.aws_partition.current.partition
}

# Identity Center Permission Sets (includes defaults + custom)
resource "aws_ssoadmin_permission_set" "this" {
  for_each = local.all_permission_sets

  instance_arn     = var.identity_center_instance_arn
  name             = each.key
  description      = each.value.description
  session_duration = each.value.session_duration

  tags = merge(local.common_tags, {
    Name        = each.key
    Type        = "permission-set"
    AccessLevel = each.value.access_level
  })
}

# Attach AWS Managed Policies to Permission Sets (includes defaults + custom)
resource "aws_ssoadmin_managed_policy_attachment" "aws_managed" {
  for_each = local.aws_managed_policy_attachments

  instance_arn       = var.identity_center_instance_arn
  managed_policy_arn = each.value.policy_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set].arn
}

# Attach Customer Managed Policies to Permission Sets (includes defaults + custom)
resource "aws_ssoadmin_customer_managed_policy_attachment" "customer_managed" {
  for_each = local.customer_managed_policy_attachments

  instance_arn       = var.identity_center_instance_arn
  customer_managed_policy_reference {
    name = each.value.policy_name
    path = each.value.policy_path
  }
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set].arn

  depends_on = [aws_iam_policy.custom_policies]
}

# Inline Policies for Permission Sets (includes defaults + custom)
resource "aws_ssoadmin_permission_set_inline_policy" "this" {
  for_each = {
    for k, v in local.all_permission_sets : k => v
    if v.inline_policy != null
  }

  instance_arn       = var.identity_center_instance_arn
  inline_policy      = each.value.inline_policy
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
}

# Account Assignments (includes defaults + custom)
resource "aws_ssoadmin_account_assignment" "this" {
  for_each = local.account_assignments

  instance_arn       = var.identity_center_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set].arn

  principal_id   = each.value.principal_id
  principal_type = each.value.principal_type
  target_id      = each.value.target_id
  target_type    = each.value.target_type
}

locals {
  # Flatten AWS managed policy attachments (includes defaults + custom)
  aws_managed_policy_attachments = merge([
    for ps_name, ps_config in local.all_permission_sets : {
      for policy_arn in ps_config.aws_managed_policies : "${ps_name}-${replace(policy_arn, "/", "-")}" => {
        permission_set = ps_name
        policy_arn     = policy_arn
      }
    }
  ]...)

  # Flatten customer managed policy attachments (includes defaults + custom)
  customer_managed_policy_attachments = merge([
    for ps_name, ps_config in local.all_permission_sets : {
      for policy_ref in ps_config.customer_managed_policies : "${ps_name}-${policy_ref.name}" => {
        permission_set = ps_name
        policy_name    = policy_ref.name
        policy_path    = policy_ref.path
      }
    }
  ]...)

  # Flatten account assignments (includes defaults + custom)
  account_assignments = merge([
    for ps_name, ps_config in local.all_permission_sets : {
      for idx, assignment in ps_config.account_assignments : "${ps_name}-${idx}" => merge(assignment, {
        permission_set = ps_name
      })
    }
  ]...)
}

# Custom IAM Policies for Enhanced Security
resource "aws_iam_policy" "custom_policies" {
  for_each = var.custom_policies

  name        = each.key
  description = each.value.description
  path        = each.value.path
  policy      = each.value.policy_document

  tags = merge(local.common_tags, {
    Name = each.key
    Type = "custom-policy"
  })
}

# EKS-specific IAM Roles and Policies (includes defaults + custom)
resource "aws_iam_role" "eks_roles" {
  for_each = local.all_eks_roles

  name = "${var.environment}-${each.key}"
  path = each.value.path

  # Dynamic trust policy handling for IRSA roles
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = each.value.principal.Federated != null ? {
          # IRSA role - replace placeholders with actual values
          Federated = replace(
            replace(each.value.principal.Federated, "PLACEHOLDER_OIDC_PROVIDER_ARN", try(var.eks_oidc_provider_arn, "")),
            "PLACEHOLDER_OIDC_PROVIDER_ARN", try(var.eks_oidc_provider_arn, "")
          )
        } : {
          # Service role - use as-is
          Service   = try(each.value.principal.Service, [])
          AWS       = try(each.value.principal.AWS, [])
        }
        Condition = each.value.principal.Federated != null ? {
          # IRSA role - replace placeholders in conditions
          for condition_key, condition_value in each.value.conditions : 
            condition_key => {
              for k, v in condition_value :
                replace(k, "PLACEHOLDER_OIDC_PROVIDER", replace(try(var.eks_oidc_provider_arn, ""), "/^.*provider\\//", "")) => v
            }
        } : each.value.conditions
      }
    ]
  })

  max_session_duration  = each.value.max_session_duration
  force_detach_policies = true

  tags = merge(local.common_tags, {
    Name    = "${var.environment}-${each.key}"
    Type    = "eks-role"
    Purpose = each.value.purpose
  })
}

# Attach policies to EKS roles
resource "aws_iam_role_policy_attachment" "eks_role_policies" {
  for_each = local.eks_role_policy_attachments

  role       = aws_iam_role.eks_roles[each.value.role_name].name
  policy_arn = each.value.policy_arn
}

# Custom policies for EKS roles
resource "aws_iam_role_policy" "eks_role_inline_policies" {
  for_each = local.eks_role_inline_policies

  name = each.value.policy_name
  role = aws_iam_role.eks_roles[each.value.role_name].name
  policy = each.value.policy_document
}

locals {
  # Flatten EKS role policy attachments (includes defaults + custom)
  eks_role_policy_attachments = merge([
    for role_name, role_config in local.all_eks_roles : {
      for policy_arn in role_config.managed_policies : "${role_name}-${replace(policy_arn, "/", "-")}" => {
        role_name  = role_name
        policy_arn = policy_arn
      }
    }
  ]...)

  # Flatten EKS role inline policies (includes defaults + custom)
  eks_role_inline_policies = merge([
    for role_name, role_config in local.all_eks_roles : {
      for policy_name, policy_doc in role_config.inline_policies : "${role_name}-${policy_name}" => {
        role_name       = role_name
        policy_name     = policy_name
        policy_document = policy_doc
      }
    }
  ]...)
}

# Cross-Account Trust Relationships
resource "aws_iam_role" "cross_account_roles" {
  for_each = var.cross_account_roles

  name = "${var.environment}-${each.key}"
  path = each.value.path

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = each.value.trusted_accounts
        }
        Condition = each.value.conditions
      }
    ]
  })

  max_session_duration = each.value.max_session_duration

  tags = merge(local.common_tags, {
    Name    = "${var.environment}-${each.key}"
    Type    = "cross-account-role"
    Purpose = each.value.purpose
  })
}

# Service-Linked Roles (when needed)
resource "aws_iam_service_linked_role" "this" {
  for_each = var.service_linked_roles

  aws_service_name = each.value.service_name
  description      = each.value.description
  custom_suffix    = each.value.custom_suffix

  tags = merge(local.common_tags, {
    Name    = each.key
    Type    = "service-linked-role"
    Service = each.value.service_name
  })
}

# OIDC Identity Providers (for external integrations)
resource "aws_iam_openid_connect_provider" "this" {
  for_each = var.oidc_providers

  url             = each.value.url
  client_id_list  = each.value.client_ids
  thumbprint_list = each.value.thumbprints

  tags = merge(local.common_tags, {
    Name     = each.key
    Type     = "oidc-provider"
    Provider = each.value.provider_name
  })
}

# Security Best Practices - Password Policy
resource "aws_iam_account_password_policy" "this" {
  count = var.enable_password_policy ? 1 : 0

  minimum_password_length        = var.password_policy.minimum_length
  require_lowercase_characters   = var.password_policy.require_lowercase
  require_numbers               = var.password_policy.require_numbers
  require_uppercase_characters   = var.password_policy.require_uppercase
  require_symbols               = var.password_policy.require_symbols
  allow_users_to_change_password = var.password_policy.allow_users_to_change
  hard_expiry                   = var.password_policy.hard_expiry
  max_password_age              = var.password_policy.max_age
  password_reuse_prevention     = var.password_policy.reuse_prevention
}

# Access Analyzer
resource "aws_accessanalyzer_analyzer" "this" {
  count = var.enable_access_analyzer ? 1 : 0

  analyzer_name = "${var.environment}-access-analyzer"
  type          = "ACCOUNT"

  tags = merge(local.common_tags, {
    Name = "${var.environment}-access-analyzer"
    Type = "security-analyzer"
  })
}

# IAM Access Analyzer Findings (for monitoring)
resource "aws_cloudwatch_log_group" "access_analyzer" {
  count = var.enable_access_analyzer ? 1 : 0

  name              = "/aws/iam/${var.environment}/access-analyzer"
  retention_in_days = var.access_analyzer_log_retention

  tags = local.common_tags
}

# Emergency Break Glass Role
resource "aws_iam_role" "break_glass" {
  count = var.enable_break_glass_role ? 1 : 0

  name = "${var.environment}-emergency-break-glass"
  path = "/emergency/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.break_glass_trusted_principals
        }
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
          NumericLessThan = {
            "aws:MultiFactorAuthAge" = "3600"  # 1 hour
          }
        }
      }
    ]
  })

  max_session_duration = 3600  # 1 hour maximum

  tags = merge(local.common_tags, {
    Name    = "${var.environment}-emergency-break-glass"
    Type    = "break-glass-role"
    Purpose = "Emergency access for critical incidents"
  })
}

# Break Glass Role Policy (Admin access with conditions)
resource "aws_iam_role_policy" "break_glass" {
  count = var.enable_break_glass_role ? 1 : 0

  name = "EmergencyBreakGlassPolicy"
  role = aws_iam_role.break_glass[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      },
      {
        Effect = "Deny"
        Action = [
          "iam:DeleteRole",
          "iam:DeleteUser",
          "iam:DeletePolicy",
          "organizations:LeaveOrganization",
          "account:CloseAccount"
        ]
        Resource = "*"
      }
    ]
  })
}