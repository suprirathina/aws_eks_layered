# EKS Module Outputs - For integration with other modules and applications

# Cluster Information
output "cluster_id" {
  description = "Name/ID of the EKS cluster"
  value       = aws_eks_cluster.main.id
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS cluster API server"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_platform_version" {
  description = "Platform version for the EKS cluster"
  value       = aws_eks_cluster.main.platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster"
  value       = aws_eks_cluster.main.status
}

# Security Information
output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

# OIDC Information for IRSA
output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

# IAM Role Information
output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = aws_iam_role.cluster.name
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN associated with EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "node_groups_iam_role_name" {
  description = "IAM role name associated with EKS node groups"
  value       = aws_iam_role.node_group.name
}

output "node_groups_iam_role_arn" {
  description = "IAM role ARN associated with EKS node groups"
  value       = aws_iam_role.node_group.arn
}

# Node Groups Information
output "managed_node_groups" {
  description = "Map of managed node groups and their attributes"
  value = {
    for k, v in aws_eks_node_group.main : k => {
      arn           = v.arn
      status        = v.status
      capacity_type = v.capacity_type
      instance_types = v.instance_types
      ami_type      = v.ami_type
      node_role_arn = v.node_role_arn
      subnet_ids    = v.subnet_ids
      version       = v.version
      
      scaling_config = v.scaling_config
      update_config  = v.update_config
      
      # Auto Scaling Group information
      resources = v.resources
    }
  }
}

# Fargate Profiles Information
output "fargate_profiles" {
  description = "Map of Fargate profiles and their attributes"
  value = {
    for k, v in aws_eks_fargate_profile.main : k => {
      arn               = v.arn
      status           = v.status
      pod_execution_role_arn = v.pod_execution_role_arn
      subnet_ids       = v.subnet_ids
    }
  }
}

# Add-on Information
output "cluster_addons" {
  description = "Map of cluster addons"
  value = {
    for k, v in aws_eks_addon.main : k => {
      arn           = v.arn
      addon_version = v.addon_version
      status        = v.status
      created_at    = v.created_at
      modified_at   = v.modified_at
    }
  }
}

# Access Configuration
output "access_entries" {
  description = "Map of access entries"
  value = {
    for k, v in aws_eks_access_entry.identity_center : k => {
      principal_arn     = v.principal_arn
      kubernetes_groups = v.kubernetes_groups
      type             = v.type
      created_at       = v.created_at
      modified_at      = v.modified_at
    }
  }
}

# Security and Encryption
output "kms_key_arn" {
  description = "ARN of the KMS key used for EKS cluster encryption"
  value       = var.enable_cluster_encryption ? aws_kms_key.eks[0].arn : null
}

output "kms_key_id" {
  description = "ID of the KMS key used for EKS cluster encryption"
  value       = var.enable_cluster_encryption ? aws_kms_key.eks[0].key_id : null
}

# CloudWatch Log Group
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for EKS cluster logs"
  value       = aws_cloudwatch_log_group.eks_cluster.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for EKS cluster logs"
  value       = aws_cloudwatch_log_group.eks_cluster.arn
}

# IRSA Role ARNs for Add-ons
output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller"
  value       = var.enable_aws_load_balancer_controller ? aws_iam_role.aws_load_balancer_controller[0].arn : null
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of the IAM role for Cluster Autoscaler"
  value       = var.enable_cluster_autoscaler ? aws_iam_role.cluster_autoscaler[0].arn : null
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the IAM role for EBS CSI Driver"
  value       = var.enable_ebs_csi_driver ? aws_iam_role.ebs_csi_driver[0].arn : null
}

output "external_secrets_role_arn" {
  description = "ARN of the IAM role for External Secrets Operator"
  value       = var.enable_external_secrets ? aws_iam_role.external_secrets[0].arn : null
}

# kubectl Configuration
output "kubeconfig_certificate_authority_data" {
  description = "Certificate authority data for kubectl configuration"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "kubectl_config" {
  description = "kubectl configuration for connecting to the cluster"
  value = {
    cluster_name                     = aws_eks_cluster.main.name
    endpoint                        = aws_eks_cluster.main.endpoint
    certificate_authority_data      = aws_eks_cluster.main.certificate_authority[0].data
    region                         = data.aws_region.current.name
    
    # For AWS CLI profile authentication
    aws_profile_command = "aws eks get-token --cluster-name ${aws_eks_cluster.main.name} --region ${data.aws_region.current.name}"
  }
}

# Network Information
output "vpc_id" {
  description = "VPC ID where the cluster is deployed"
  value       = var.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs where the cluster is deployed"
  value       = var.subnet_ids
}

# Security Group Information
output "additional_security_group_id" {
  description = "ID of the additional security group created for the cluster"
  value       = var.create_additional_security_group ? aws_security_group.cluster_additional[0].id : null
}

# Cluster Tags
output "cluster_tags" {
  description = "Map of tags assigned to the cluster"
  value       = aws_eks_cluster.main.tags
}

# For Kubernetes Provider Configuration
output "cluster_ca_certificate" {
  description = "Base64 decoded certificate authority data"
  value       = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
}

# EKS Managed Add-on Default Versions
output "addon_default_versions" {
  description = "Default versions for EKS managed add-ons"
  value = {
    coredns    = "latest"
    kube-proxy = "latest"
    vpc-cni    = "latest"
    ebs-csi    = "latest"
  }
}

# IRSA Helper Information
output "irsa_oidc_provider_url" {
  description = "OIDC provider URL for IRSA (without https://)"
  value       = local.oidc_issuer_url
}

output "irsa_namespace_service_account_mapping" {
  description = "Helper mapping for common IRSA service accounts"
  value = {
    aws_load_balancer_controller = {
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
      role_arn       = var.enable_aws_load_balancer_controller ? aws_iam_role.aws_load_balancer_controller[0].arn : null
    }
    cluster_autoscaler = {
      namespace       = "kube-system"
      service_account = "cluster-autoscaler"
      role_arn       = var.enable_cluster_autoscaler ? aws_iam_role.cluster_autoscaler[0].arn : null
    }
    ebs_csi_driver = {
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
      role_arn       = var.enable_ebs_csi_driver ? aws_iam_role.ebs_csi_driver[0].arn : null
    }
    external_secrets = {
      namespace       = "external-secrets-system"
      service_account = "external-secrets"
      role_arn       = var.enable_external_secrets ? aws_iam_role.external_secrets[0].arn : null
    }
  }
}