#####################################
# ECR MODULE - Enterprise Container Registry
#####################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Dynamic ECR Repositories
resource "aws_ecr_repository" "repositories" {
  for_each = var.repositories

  name                 = "${var.project_name}-${var.environment}-${each.key}"
  image_tag_mutability = each.value.image_tag_mutability

  # Enable image scanning for security
  image_scanning_configuration {
    scan_on_push = each.value.scan_on_push
  }

  # Encryption configuration
  encryption_configuration {
    encryption_type = each.value.encryption_type
    kms_key        = each.value.encryption_type == "KMS" ? each.value.kms_key_id : null
  }

  # Force delete for POC environments (use with caution)
  force_delete = each.value.force_delete

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${each.key}"
    Module      = "ecr"
    Application = each.value.application
  })
}

# Dynamic Lifecycle Policies
resource "aws_ecr_lifecycle_policy" "lifecycle_policies" {
  for_each = {
    for name, repo in var.repositories : name => repo
    if repo.lifecycle_policy != null
  }

  repository = aws_ecr_repository.repositories[each.key].name

  policy = jsonencode({
    rules = each.value.lifecycle_policy.rules
  })
}

# Repository Policies for Cross-Account Access
resource "aws_ecr_repository_policy" "repository_policies" {
  for_each = {
    for name, repo in var.repositories : name => repo
    if repo.cross_account_access != null
  }

  repository = aws_ecr_repository.repositories[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CrossAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = each.value.cross_account_access.principals
        }
        Action = each.value.cross_account_access.actions
      }
    ]
  })
}

# IAM Role for ECR Pull-Through Cache (optional)
resource "aws_iam_role" "ecr_pull_through" {
  count = var.enable_pull_through_cache ? 1 : 0
  name  = "${var.project_name}-${var.environment}-ecr-pull-through"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecr.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-ecr-pull-through-role"
    Module = "ecr"
  })
}

# Pull-Through Cache Rules
resource "aws_ecr_pull_through_cache_rule" "cache_rules" {
  for_each = var.enable_pull_through_cache ? var.pull_through_cache_rules : {}

  ecr_repository_prefix = each.value.repository_prefix
  upstream_registry_url = each.value.upstream_registry_url
  credential_arn        = each.value.credential_arn
}

# CloudWatch Log Group for ECR Image Scan Results
resource "aws_cloudwatch_log_group" "ecr_scan_results" {
  count             = var.enable_scan_logging ? 1 : 0
  name              = "/aws/ecr/${var.project_name}-${var.environment}-scan-results"
  retention_in_days = var.scan_log_retention_days
  kms_key_id        = var.scan_log_kms_key_id

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-ecr-scan-logs"
    Module      = "ecr"
    Application = "security"
  })
}

# ECR Registry Scanning Configuration (optional)
resource "aws_ecr_registry_scanning_configuration" "registry_scanning" {
  count = var.enable_registry_scanning ? 1 : 0

  scan_type = var.registry_scan_type

  dynamic "rule" {
    for_each = var.registry_scan_rules
    content {
      scan_frequency = rule.value.scan_frequency
      repository_filter {
        filter      = rule.value.repository_filter
        filter_type = rule.value.filter_type
      }
    }
  }
}

# ECR Replication Configuration (optional)
resource "aws_ecr_replication_configuration" "replication" {
  count = var.enable_replication ? 1 : 0

  replication_configuration {
    dynamic "rule" {
      for_each = var.replication_rules
      content {
        dynamic "destination" {
          for_each = rule.value.destinations
          content {
            region      = destination.value.region
            registry_id = destination.value.registry_id
          }
        }
        
        dynamic "repository_filter" {
          for_each = rule.value.repository_filters
          content {
            filter      = repository_filter.value.filter
            filter_type = repository_filter.value.filter_type
          }
        }
      }
    }
  }
}

# KMS Key for ECR Encryption (optional)
resource "aws_kms_key" "ecr" {
  count                   = var.create_kms_key ? 1 : 0
  description             = "KMS key for ECR encryption - ${var.project_name} ${var.environment}"
  deletion_window_in_days = var.kms_key_deletion_window

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow ECR Service"
        Effect = "Allow"
        Principal = {
          Service = "ecr.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-ecr-kms"
    Module = "ecr"
  })
}

resource "aws_kms_alias" "ecr" {
  count         = var.create_kms_key ? 1 : 0
  name          = "alias/${var.project_name}-${var.environment}-ecr"
  target_key_id = aws_kms_key.ecr[0].key_id
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}