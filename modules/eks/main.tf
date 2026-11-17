# Enterprise EKS Module with Security Best Practices
# Private cluster with IRSA, managed node groups, and comprehensive security

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# EKS Optimized AMI
data "aws_ssm_parameter" "eks_ami_release_version" {
  name = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2/recommended/release_version"
}

locals {
  # Common tags for all resources
  common_tags = merge(
    var.tags,
    {
      Module      = "eks"
      Environment = var.environment
      ManagedBy   = "terraform"
      Cluster     = var.cluster_name
    }
  )

  # OIDC issuer URL without https://
  oidc_issuer_url = replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
}

# KMS key for EKS encryption
resource "aws_kms_key" "eks" {
  count = var.enable_cluster_encryption ? 1 : 0

  description = "EKS Secret Encryption Key for ${var.cluster_name}"
  
  key_usage   = "ENCRYPT_DECRYPT"
  key_spec    = "SYMMETRIC_DEFAULT"

  # Enable automatic rotation
  enable_key_rotation = true

  # Deletion protection
  deletion_window_in_days = var.kms_key_deletion_window

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-eks-encryption-key"
  })
}

resource "aws_kms_alias" "eks" {
  count = var.enable_cluster_encryption ? 1 : 0

  name          = "alias/${var.cluster_name}-eks-encryption"
  target_key_id = aws_kms_key.eks[0].key_id
}

# CloudWatch Log Group for EKS Control Plane Logs
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_retention_days
  kms_key_id        = var.enable_cluster_encryption ? aws_kms_key.eks[0].arn : null

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-cluster-logs"
  })
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  # Private cluster configuration
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : []
    
    # Security groups
    security_group_ids = var.additional_security_group_ids
  }

  # Enable all control plane logging by default
  enabled_cluster_log_types = var.cluster_log_types

  # Encryption configuration
  dynamic "encryption_config" {
    for_each = var.enable_cluster_encryption ? [1] : []
    content {
      provider {
        key_arn = aws_kms_key.eks[0].arn
      }
      resources = ["secrets"]
    }
  }

  # Kubernetes network configuration
  kubernetes_network_config {
    service_ipv4_cidr = var.cluster_service_ipv4_cidr
    ip_family         = "ipv4"
  }

  # Access configuration (EKS Access Entries)
  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions
  }

  # Ensure proper ordering
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
    aws_cloudwatch_log_group.eks_cluster
  ]

  tags = local.common_tags
}

# OIDC Identity Provider for IRSA
data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-oidc-provider"
  })
}

# EKS Managed Node Groups
resource "aws_eks_node_group" "main" {
  for_each = var.managed_node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.node_group_subnet_ids

  # Instance configuration
  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type
  ami_type       = each.value.ami_type
  disk_size      = each.value.disk_size

  # Scaling configuration
  scaling_config {
    desired_size = each.value.desired_capacity
    max_size     = each.value.max_capacity
    min_size     = each.value.min_capacity
  }

  # Update configuration
  update_config {
    max_unavailable_percentage = each.value.max_unavailable_percentage
  }

  # Launch template configuration
  dynamic "launch_template" {
    for_each = each.value.launch_template != null ? [each.value.launch_template] : []
    content {
      id      = launch_template.value.id
      version = launch_template.value.version
    }
  }

  # Remote access (disabled by default for security)
  dynamic "remote_access" {
    for_each = each.value.enable_remote_access ? [1] : []
    content {
      ec2_ssh_key               = each.value.key_name
      source_security_group_ids = each.value.source_security_group_ids
    }
  }

  # Taints
  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  # Labels
  labels = merge(
    each.value.labels,
    {
      Environment = var.environment
      NodeGroup   = each.key
    }
  )

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-${each.key}"
  })

  # Ensure proper ordering
  depends_on = [
    aws_iam_role_policy_attachment.node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_group_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_group_AmazonEC2ContainerRegistryReadOnly,
  ]
}

# EKS Fargate Profiles (optional)
resource "aws_eks_fargate_profile" "main" {
  for_each = var.fargate_profiles

  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = each.key
  pod_execution_role_arn = aws_iam_role.fargate_pod[0].arn
  subnet_ids            = var.fargate_subnet_ids

  dynamic "selector" {
    for_each = each.value.selectors
    content {
      namespace = selector.value.namespace
      labels    = selector.value.labels
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-${each.key}-fargate"
  })

  depends_on = [
    aws_iam_role_policy_attachment.fargate_pod_AmazonEKSFargatePodExecutionRolePolicy,
  ]
}

# EKS Access Entries for Identity Center Integration
resource "aws_eks_access_entry" "identity_center" {
  for_each = var.access_entries

  cluster_name      = aws_eks_cluster.main.name
  principal_arn     = each.value.principal_arn
  kubernetes_groups = each.value.kubernetes_groups
  type             = each.value.type

  tags = merge(local.common_tags, {
    Name      = "${var.cluster_name}-access-${each.key}"
    Principal = each.key
  })
}

# Associate access policies
resource "aws_eks_access_policy_association" "identity_center" {
  for_each = {
    for k, v in var.access_entries : k => v
    if length(v.policy_associations) > 0
  }

  cluster_name = aws_eks_cluster.main.name
  
  dynamic "policy_arn" {
    for_each = each.value.policy_associations
    content {
      policy_arn = policy_arn.value.policy_arn
    }
  }

  principal_arn = each.value.principal_arn

  dynamic "access_scope" {
    for_each = each.value.policy_associations
    content {
      type       = access_scope.value.access_scope.type
      namespaces = access_scope.value.access_scope.namespaces
    }
  }

  depends_on = [aws_eks_access_entry.identity_center]
}

# EKS Add-ons
resource "aws_eks_addon" "main" {
  for_each = var.cluster_addons

  cluster_name             = aws_eks_cluster.main.name
  addon_name               = each.key
  addon_version           = each.value.addon_version
  service_account_role_arn = each.value.service_account_role_arn
  resolve_conflicts_on_create = each.value.resolve_conflicts
  resolve_conflicts_on_update = each.value.resolve_conflicts

  # Configuration values
  configuration_values = each.value.configuration_values

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-${each.key}-addon"
  })

  depends_on = [aws_eks_node_group.main]
}

# Security Group for additional EKS security
resource "aws_security_group" "cluster_additional" {
  count = var.create_additional_security_group ? 1 : 0

  name_prefix = "${var.cluster_name}-additional-"
  description = "Additional security group for EKS cluster ${var.cluster_name}"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-additional-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Additional security group rules
resource "aws_security_group_rule" "cluster_additional_ingress" {
  for_each = var.create_additional_security_group ? var.additional_security_group_rules : {}

  type                     = "ingress"
  from_port               = each.value.from_port
  to_port                 = each.value.to_port
  protocol                = each.value.protocol
  security_group_id       = aws_security_group.cluster_additional[0].id
  source_security_group_id = each.value.source_security_group_id
  cidr_blocks             = each.value.cidr_blocks
  description             = each.value.description
}