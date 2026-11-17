# ECR Module Outputs

# Repository Information
output "repository_urls" {
  description = "URLs of all ECR repositories"
  value = {
    for name, repo in aws_ecr_repository.repositories : name => repo.repository_url
  }
}

output "repository_arns" {
  description = "ARNs of all ECR repositories"
  value = {
    for name, repo in aws_ecr_repository.repositories : name => repo.arn
  }
}

output "repository_names" {
  description = "Names of all ECR repositories"
  value = {
    for name, repo in aws_ecr_repository.repositories : name => repo.name
  }
}

output "registry_id" {
  description = "Registry ID (AWS account ID)"
  value       = length(aws_ecr_repository.repositories) > 0 ? values(aws_ecr_repository.repositories)[0].registry_id : null
}

# KMS Information
output "kms_key_id" {
  description = "KMS key ID for ECR encryption (if created)"
  value       = var.create_kms_key ? aws_kms_key.ecr[0].key_id : null
}

output "kms_key_arn" {
  description = "KMS key ARN for ECR encryption (if created)"
  value       = var.create_kms_key ? aws_kms_key.ecr[0].arn : null
}

# Pull-Through Cache Information
output "pull_through_cache_rules" {
  description = "Pull-through cache rule information"
  value = var.enable_pull_through_cache ? {
    for name, rule in aws_ecr_pull_through_cache_rule.cache_rules : name => {
      repository_prefix     = rule.ecr_repository_prefix
      upstream_registry_url = rule.upstream_registry_url
      registry_id          = rule.registry_id
    }
  } : {}
}

# Scan Logging Information
output "scan_log_group_name" {
  description = "CloudWatch log group name for ECR scan results"
  value       = var.enable_scan_logging ? aws_cloudwatch_log_group.ecr_scan_results[0].name : null
}

output "scan_log_group_arn" {
  description = "CloudWatch log group ARN for ECR scan results"
  value       = var.enable_scan_logging ? aws_cloudwatch_log_group.ecr_scan_results[0].arn : null
}

# Docker Commands for Reference
output "docker_login_command" {
  description = "AWS CLI command to authenticate Docker with ECR"
  value       = length(aws_ecr_repository.repositories) > 0 ? "aws ecr get-login-password --region ${data.aws_caller_identity.current.id} | docker login --username AWS --password-stdin ${values(aws_ecr_repository.repositories)[0].registry_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com" : null
}

output "docker_build_push_commands" {
  description = "Example Docker build and push commands for each repository"
  value = {
    for name, repo in aws_ecr_repository.repositories : name => {
      build = "docker build -t ${name} ."
      tag   = "docker tag ${name}:latest ${repo.repository_url}:latest"
      push  = "docker push ${repo.repository_url}:latest"
    }
  }
}

# Configuration Summary
output "configuration_summary" {
  description = "Summary of ECR module configuration"
  value = {
    repository_count         = length(aws_ecr_repository.repositories)
    pull_through_cache_enabled = var.enable_pull_through_cache
    scan_logging_enabled     = var.enable_scan_logging
    registry_scanning_enabled = var.enable_registry_scanning
    replication_enabled      = var.enable_replication
    kms_encryption_enabled   = var.create_kms_key
    repositories = {
      for name, config in var.repositories : name => {
        image_tag_mutability = config.image_tag_mutability
        scan_on_push         = config.scan_on_push
        encryption_type      = config.encryption_type
        application         = config.application
        has_lifecycle_policy = config.lifecycle_policy != null
        cross_account_access = config.cross_account_access != null
      }
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}