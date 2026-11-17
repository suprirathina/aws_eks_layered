# Secrets Module Outputs

# Secrets Information
output "secrets" {
  description = "Information about all created secrets"
  value = {
    for name, secret in aws_secretsmanager_secret.secrets : name => {
      name = secret.name
      arn  = secret.arn
      id   = secret.id
    }
  }
}

output "secret_arns" {
  description = "ARNs of all secrets"
  value = {
    for name, secret in aws_secretsmanager_secret.secrets : name => secret.arn
  }
}

output "secret_names" {
  description = "Names of all secrets"
  value = {
    for name, secret in aws_secretsmanager_secret.secrets : name => secret.name
  }
}

# External Secrets Operator Information
output "external_secrets_role_arn" {
  description = "IAM role ARN for External Secrets Operator"
  value       = var.enable_external_secrets_operator ? aws_iam_role.external_secrets[0].arn : null
}

output "external_secrets_role_name" {
  description = "IAM role name for External Secrets Operator"
  value       = var.enable_external_secrets_operator ? aws_iam_role.external_secrets[0].name : null
}

# KMS Information
output "kms_key_id" {
  description = "KMS key ID for secrets encryption (if created)"
  value       = var.create_kms_key ? aws_kms_key.secrets[0].key_id : null
}

output "kms_key_arn" {
  description = "KMS key ARN for secrets encryption (if created)"
  value       = var.create_kms_key ? aws_kms_key.secrets[0].arn : null
}

output "kms_alias_name" {
  description = "KMS key alias name (if created)"
  value       = var.create_kms_key ? aws_kms_alias.secrets[0].name : null
}

# Logging Information
output "access_log_group_name" {
  description = "CloudWatch log group name for secrets access logging"
  value       = var.enable_access_logging ? aws_cloudwatch_log_group.secrets_access[0].name : null
}

output "access_log_group_arn" {
  description = "CloudWatch log group ARN for secrets access logging"
  value       = var.enable_access_logging ? aws_cloudwatch_log_group.secrets_access[0].arn : null
}

# Random Values (for reference, not sensitive)
output "random_password_info" {
  description = "Information about generated random passwords (non-sensitive)"
  value = {
    for name, config in var.random_passwords : name => {
      length  = config.length
      special = config.special
    }
  }
}

output "random_id_values" {
  description = "Generated random ID values (non-sensitive)"
  value = {
    for name, id in random_id.ids : name => id.hex
  }
}

# Lambda Rotation Functions
output "rotation_functions" {
  description = "Information about Lambda rotation functions"
  value = {
    for name, func in aws_lambda_function.rotation_functions : name => {
      function_name = func.function_name
      arn           = func.arn
    }
  }
}

# Kubernetes Integration
output "k8s_examples_file" {
  description = "Path to Kubernetes secret examples file"
  value       = var.create_k8s_examples ? local_file.k8s_secret_examples[0].filename : null
}

output "external_secrets_setup" {
  description = "Commands to set up External Secrets Operator"
  value = var.enable_external_secrets_operator ? {
    helm_repo_add = "helm repo add external-secrets https://charts.external-secrets.io"
    helm_install  = "helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace --set serviceAccount.annotations.\"eks\\.amazonaws\\.com/role-arn\"=${aws_iam_role.external_secrets[0].arn}"
    verify_pods   = "kubectl get pods -n external-secrets-system"
  } : {}
}

# CLI Commands for Secret Management
output "cli_commands" {
  description = "Useful AWS CLI commands for secret management"
  value = {
    list_secrets = "aws secretsmanager list-secrets --query 'SecretList[?Tags[?Key==`Project` && Value==`${var.project_name}`]]'"
    get_secret_template = "aws secretsmanager get-secret-value --secret-id <secret-name> --query SecretString --output text"
    create_secret_template = "aws secretsmanager create-secret --name <secret-name> --description '<description>' --secret-string '<json-string>'"
  }
}

# Cross-Region Replication Information
output "secret_replications" {
  description = "Information about cross-region secret replications"
  value = {
    for name, replication in aws_secretsmanager_secret_replication.cross_region : name => {
      secret_arn = replication.secret_id
      replicas   = replication.replica
    }
  }
}

# Configuration Summary
output "configuration_summary" {
  description = "Summary of secrets module configuration"
  value = {
    total_secrets                = length(aws_secretsmanager_secret.secrets)
    external_secrets_enabled     = var.enable_external_secrets_operator
    kms_encryption_enabled       = var.create_kms_key
    access_logging_enabled       = var.enable_access_logging
    k8s_examples_created        = var.create_k8s_examples
    rotation_functions_count    = length(aws_lambda_function.rotation_functions)
    cross_region_replications   = length(aws_secretsmanager_secret_replication.cross_region)
    secret_policies_count       = length(aws_secretsmanager_secret_policy.secret_policies)
    
    secrets_by_type = {
      for secret_type in distinct([for s in var.secrets : s.secret_type]) : secret_type => length([
        for name, config in var.secrets : name if config.secret_type == secret_type
      ])
    }
    
    secrets_by_application = {
      for app in distinct([for s in var.secrets : s.application]) : app => length([
        for name, config in var.secrets : name if config.application == app
      ])
    }
  }
}

# Cost Estimation
output "estimated_monthly_cost" {
  description = "Estimated monthly cost for secrets management"
  value = {
    secrets_storage = "$${length(aws_secretsmanager_secret.secrets) * 0.40}"
    api_calls_estimated = "Variable based on usage (~$0.05 per 10,000 API calls)"
    kms_key_cost = var.create_kms_key ? "$1.00" : "$0.00"
    lambda_rotation_cost = "$${length(aws_lambda_function.rotation_functions) * 0.20} (estimated)"
    cloudwatch_logs_cost = var.enable_access_logging ? "Variable based on log volume" : "$0.00"
    total_fixed_monthly = "$${length(aws_secretsmanager_secret.secrets) * 0.40 + (var.create_kms_key ? 1.00 : 0.00)}"
  }
}