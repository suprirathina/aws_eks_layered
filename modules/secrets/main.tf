#####################################
# SECRETS MODULE - Enterprise Credential Security
#####################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# Dynamic Secrets Management
resource "aws_secretsmanager_secret" "secrets" {
  for_each = var.secrets

  name                    = "${var.project_name}-${var.environment}-${each.key}"
  description             = each.value.description
  recovery_window_in_days = each.value.recovery_window_in_days

  # Enable automatic rotation (optional)
  dynamic "rotation_rules" {
    for_each = each.value.enable_rotation ? [1] : []
    content {
      automatically_after_days = each.value.rotation_interval_days
    }
  }

  # KMS encryption
  kms_key_id = each.value.kms_key_id

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${each.key}"
    Module      = "secrets"
    Application = each.value.application
    SecretType  = each.value.secret_type
  })
}

# Generate random passwords
resource "random_password" "passwords" {
  for_each = var.random_passwords

  length  = each.value.length
  special = each.value.special
  upper   = each.value.upper
  lower   = each.value.lower
  numeric = each.value.numeric
  
  # Override characters if specified
  override_special = each.value.override_special
  min_lower       = each.value.min_lower
  min_upper       = each.value.min_upper
  min_numeric     = each.value.min_numeric
  min_special     = each.value.min_special

  # Keepers for regeneration
  keepers = each.value.keepers
}

# Generate random IDs/suffixes
resource "random_id" "ids" {
  for_each = var.random_ids

  byte_length = each.value.byte_length
  prefix      = each.value.prefix
  keepers     = each.value.keepers
}

# Secret versions with dynamic content
resource "aws_secretsmanager_secret_version" "secret_versions" {
  for_each = var.secrets

  secret_id = aws_secretsmanager_secret.secrets[each.key].id
  
  # Build secret string dynamically
  secret_string = jsonencode(merge(
    each.value.static_values,
    {
      for k, v in each.value.password_references : k => random_password.passwords[v].result
    },
    {
      for k, v in each.value.id_references : k => random_id.ids[v].hex
    }
  ))

  lifecycle {
    ignore_changes = each.value.ignore_changes ? [secret_string] : null
  }

  version_stages = each.value.version_stages
}

# IAM Role for External Secrets Operator (EKS Integration)
resource "aws_iam_role" "external_secrets" {
  count = var.enable_external_secrets_operator ? 1 : 0
  name  = "${var.project_name}-${var.environment}-external-secrets"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.eks_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = merge(
            {
              "${replace(var.eks_oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
            },
            var.external_secrets_service_account != "" ? {
              "${replace(var.eks_oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = var.external_secrets_service_account
            } : {}
          )
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-external-secrets-role"
    Module = "secrets"
  })
}

# IAM Policy for External Secrets Operator
resource "aws_iam_role_policy" "external_secrets" {
  count = var.enable_external_secrets_operator ? 1 : 0
  name  = "${var.project_name}-${var.environment}-external-secrets-policy"
  role  = aws_iam_role.external_secrets[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          for secret in aws_secretsmanager_secret.secrets : secret.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "secretsmanager:ResourceTag/Project" = var.project_name
          }
        }
      }
    ]
  })
}

# Additional IAM policies for External Secrets Operator
resource "aws_iam_role_policy_attachment" "external_secrets_additional" {
  for_each = var.enable_external_secrets_operator ? toset(var.external_secrets_additional_policies) : []

  role       = aws_iam_role.external_secrets[0].name
  policy_arn = each.value
}

# KMS Key for secrets encryption (optional)
resource "aws_kms_key" "secrets" {
  count                   = var.create_kms_key ? 1 : 0
  description             = "KMS key for ${var.project_name} ${var.environment} secrets encryption"
  deletion_window_in_days = var.kms_key_deletion_window

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ],
    var.enable_external_secrets_operator ? [{
      Sid    = "Allow External Secrets Operator"
      Effect = "Allow"
      Principal = {
        AWS = aws_iam_role.external_secrets[0].arn
      }
      Action = [
        "kms:Decrypt",
        "kms:DescribeKey"
      ]
      Resource = "*"
    }] : [],
    [
      for principal in var.kms_key_additional_principals : {
        Sid    = "Allow Additional Principal"
        Effect = "Allow"
        Principal = {
          AWS = principal
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ])
  })

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-secrets-kms"
    Module = "secrets"
  })
}

resource "aws_kms_alias" "secrets" {
  count         = var.create_kms_key ? 1 : 0
  name          = "alias/${var.project_name}-${var.environment}-secrets"
  target_key_id = aws_kms_key.secrets[0].key_id
}

# CloudWatch Log Group for Secrets Manager Access Logs
resource "aws_cloudwatch_log_group" "secrets_access" {
  count             = var.enable_access_logging ? 1 : 0
  name              = "/aws/secretsmanager/${var.project_name}-${var.environment}-access"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_id

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-secrets-access-logs"
    Module      = "secrets"
    Application = "security"
  })
}

# Lambda function for secret rotation (optional)
resource "aws_lambda_function" "rotation_functions" {
  for_each = var.rotation_functions

  filename         = each.value.filename
  function_name    = "${var.project_name}-${var.environment}-${each.key}-rotation"
  role            = each.value.execution_role_arn
  handler         = each.value.handler
  runtime         = each.value.runtime
  timeout         = each.value.timeout
  memory_size     = each.value.memory_size

  # Environment variables
  environment {
    variables = each.value.environment_variables
  }

  # VPC configuration (if needed)
  dynamic "vpc_config" {
    for_each = each.value.vpc_config != null ? [each.value.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-${each.key}-rotation"
    Module = "secrets"
  })
}

# Lambda permissions for Secrets Manager
resource "aws_lambda_permission" "rotation_permissions" {
  for_each = var.rotation_functions

  statement_id  = "AllowSecretsManagerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation_functions[each.key].function_name
  principal     = "secretsmanager.amazonaws.com"
}

# Kubernetes Secret Store and External Secret examples
resource "local_file" "k8s_secret_examples" {
  count    = var.create_k8s_examples ? 1 : 0
  filename = "${path.module}/k8s-secret-examples.yaml"
  
  content = templatefile("${path.module}/k8s-examples.tpl", {
    project_name = var.project_name
    environment  = var.environment
    region       = var.region
    secrets      = aws_secretsmanager_secret.secrets
    external_secrets_role_arn = var.enable_external_secrets_operator ? aws_iam_role.external_secrets[0].arn : ""
  })

  depends_on = [aws_secretsmanager_secret.secrets]
}

# Cross-region secret replication (optional)
resource "aws_secretsmanager_secret_replication" "cross_region" {
  for_each = var.secret_replications

  secret_id = aws_secretsmanager_secret.secrets[each.value.secret_key].id

  dynamic "replica" {
    for_each = each.value.regions
    content {
      region     = replica.value.region
      kms_key_id = replica.value.kms_key_id
    }
  }
}

# Resource-based policy for secrets (optional)
resource "aws_secretsmanager_secret_policy" "secret_policies" {
  for_each = var.secret_policies

  secret_arn = aws_secretsmanager_secret.secrets[each.value.secret_key].arn
  policy     = jsonencode(each.value.policy)
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}