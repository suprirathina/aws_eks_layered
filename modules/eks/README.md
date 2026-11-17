# Enterprise EKS Module

## Overview
This module creates a **production-ready, security-hardened EKS cluster** with comprehensive IRSA support, managed node groups, and enterprise-grade security configurations.

## Security Features

### 🔒 **Cluster Security**
- **Private Cluster**: Private API endpoint by default (no public internet access)
- **Encryption at Rest**: KMS encryption for Kubernetes secrets
- **Comprehensive Logging**: All control plane logs enabled
- **IRSA Ready**: OpenID Connect provider for secure service account roles
- **Least Privilege Access**: Minimal IAM permissions with fine-grained roles

### 🛡️ **Network Security**
- **Private Node Groups**: Worker nodes in private subnets only
- **Security Groups**: Layered security group approach
- **VPC-Native**: Full integration with AWS VPC networking
- **No SSH Access**: Remote access disabled by default

### 👥 **Access Control**
- **Identity Center Integration**: Support for AWS Identity Center access entries
- **RBAC Ready**: Kubernetes role-based access control
- **API + ConfigMap**: Flexible authentication modes
- **Audit Logging**: Complete API server audit trail

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    EKS Control Plane                        │
│                   (Private Endpoint)                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Node Group  │  │ Node Group  │  │ Fargate     │        │
│  │ (AZ-1a)     │  │ (AZ-1b)     │  │ Profile     │        │
│  │             │  │             │  │ (Optional)  │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                    IRSA Integration                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │AWS Load     │  │Cluster      │  │External     │        │
│  │Balancer     │  │Autoscaler   │  │Secrets      │        │
│  │Controller   │  │             │  │Operator     │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
                          │
                    ┌─────▼─────┐
                    │   VPC     │
                    │(Private   │
                    │ Subnets)  │
                    └───────────┘
```

## Usage

### Basic Usage
```hcl
module "eks" {
  source = "../modules/eks"
  
  cluster_name = "my-cluster"
  environment  = "dev"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  managed_node_groups = {
    main = {
      instance_types   = ["t3.medium"]
      desired_capacity = 2
      max_capacity     = 4
      min_capacity     = 1
    }
  }
  
  tags = {
    Project = "my-project"
    Owner   = "platform-team"
  }
}
```

### Production Configuration
```hcl
module "eks" {
  source = "../modules/eks"
  
  cluster_name    = "production-cluster"
  cluster_version = "1.28"
  environment     = "prod"
  
  # Network Configuration
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids
  node_group_subnet_ids = module.vpc.private_subnet_ids
  
  # Security Configuration
  endpoint_private_access = true
  endpoint_public_access  = false
  enable_cluster_encryption = true
  
  # Comprehensive logging
  cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_retention_days = 90
  
  # Identity Center Integration
  access_entries = {
    eks_admins = {
      principal_arn     = "arn:aws:iam::123456789012:role/AWSReservedSSO_EKSAdmins_xxx"
      kubernetes_groups = ["system:masters"]
      policy_associations = [{
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = {
          type = "cluster"
        }
      }]
    }
    
    eks_developers = {
      principal_arn     = "arn:aws:iam::123456789012:role/AWSReservedSSO_EKSDevelopers_xxx"
      kubernetes_groups = ["developers"]
      policy_associations = [{
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
        access_scope = {
          type = "namespace"
          namespaces = ["default", "development"]
        }
      }]
    }
  }
  
  # Multi-AZ Node Groups with Mixed Instances
  managed_node_groups = {
    system = {
      instance_types   = ["t3.medium", "t3a.medium"]
      capacity_type    = "ON_DEMAND"
      desired_capacity = 3
      max_capacity     = 6
      min_capacity     = 3
      
      labels = {
        role = "system"
      }
    }
    
    applications = {
      instance_types   = ["m5.large", "m5a.large", "m4.large"]
      capacity_type    = "SPOT"
      desired_capacity = 2
      max_capacity     = 10
      min_capacity     = 0
      
      labels = {
        role = "applications"
      }
      
      taints = [{
        key    = "spot"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
  }
  
  # Fargate for Serverless Workloads
  fargate_profiles = {
    serverless = {
      selectors = [{
        namespace = "serverless"
      }]
    }
  }
  
  # IRSA Roles for Add-ons
  enable_aws_load_balancer_controller = true
  enable_cluster_autoscaler          = true
  enable_ebs_csi_driver             = true
  enable_external_secrets           = true
  
  # EKS Managed Add-ons
  cluster_addons = {
    coredns = {
      addon_version = "v1.10.1-eksbuild.7"
    }
    kube-proxy = {
      addon_version = "v1.28.4-eksbuild.4"
    }
    vpc-cni = {
      addon_version = "v1.16.0-eksbuild.1"
    }
    aws-ebs-csi-driver = {
      addon_version            = "v1.25.0-eksbuild.1"
      service_account_role_arn = module.eks.ebs_csi_driver_role_arn
    }
  }
  
  tags = {
    Environment = "production"
    Project     = "core-platform"
    Owner       = "platform-team"
    CostCenter  = "engineering"
  }
}
```

### Multi-Environment Pattern
```hcl
# Development Environment
module "eks_dev" {
  source = "../modules/eks"
  
  cluster_name = "dev-cluster"
  environment  = "dev"
  
  # Development-specific settings
  endpoint_public_access = true  # Allow public access for development
  public_access_cidrs   = ["203.0.113.0/24"]  # Office IP range
  
  managed_node_groups = {
    dev = {
      instance_types   = ["t3.small"]
      capacity_type    = "SPOT"
      desired_capacity = 1
      max_capacity     = 3
      min_capacity     = 0
    }
  }
  
  # Minimal logging for cost optimization
  cluster_log_types = ["api", "audit"]
  cloudwatch_log_retention_days = 7
}

# Production Environment
module "eks_prod" {
  source = "../modules/eks"
  
  cluster_name = "prod-cluster"
  environment  = "prod"
  
  # Production security
  endpoint_private_access = true
  endpoint_public_access  = false
  enable_cluster_encryption = true
  
  # Multi-AZ, multi-instance type for resilience
  managed_node_groups = {
    system = {
      instance_types   = ["t3.medium", "t3a.medium"]
      capacity_type    = "ON_DEMAND"
      desired_capacity = 3
      max_capacity     = 6
      min_capacity     = 3
    }
    
    workloads = {
      instance_types   = ["m5.large", "m5a.large"]
      capacity_type    = "SPOT"
      desired_capacity = 2
      max_capacity     = 20
      min_capacity     = 0
    }
  }
  
  # Comprehensive logging
  cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_retention_days = 90
}
```

## IRSA Integration

### Service Account Role Creation
```hcl
# Example: Application-specific IRSA role
resource "aws_iam_role" "my_app" {
  name = "${module.eks.cluster_name}-my-app"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${module.eks.irsa_oidc_provider_url}:sub" = "system:serviceaccount:my-namespace:my-service-account"
            "${module.eks.irsa_oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}
```

### Kubernetes Service Account Annotation
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

### 1. **Network Security**
```hcl
# Private cluster with no public access
endpoint_private_access = true
endpoint_public_access  = false

# Use private subnets only for node groups
node_group_subnet_ids = module.vpc.private_subnet_ids
```

### 2. **Encryption & Secrets**
```hcl
# Enable KMS encryption for secrets
enable_cluster_encryption = true

# Use External Secrets for secret management
enable_external_secrets = true
secrets_manager_prefix = "myapp/"
```

### 3. **Comprehensive Logging**
```hcl
# Enable all control plane logs
cluster_log_types = [
  "api",
  "audit", 
  "authenticator",
  "controllerManager",
  "scheduler"
]

# Retain logs for compliance
cloudwatch_log_retention_days = 90
```

### 4. **Access Control**
```hcl
# Use Identity Center for human access
access_entries = {
  admins = {
    principal_arn = "arn:aws:iam::account:role/AWSReservedSSO_EKSAdmins_xxx"
    kubernetes_groups = ["system:masters"]
  }
}

# Use IRSA for service access
enable_aws_load_balancer_controller = true
enable_external_secrets = true
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the EKS cluster | `string` | n/a | yes |
| environment | Environment name | `string` | n/a | yes |
| vpc_id | VPC ID for cluster | `string` | n/a | yes |
| subnet_ids | Subnet IDs for cluster | `list(string)` | n/a | yes |
| cluster_version | Kubernetes version | `string` | `"1.28"` | no |
| endpoint_private_access | Enable private endpoint | `bool` | `true` | no |
| endpoint_public_access | Enable public endpoint | `bool` | `false` | no |
| enable_cluster_encryption | Enable KMS encryption | `bool` | `true` | no |
| managed_node_groups | Map of node group configurations | `map(object)` | `{}` | no |
| access_entries | Identity Center access entries | `map(object)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_endpoint | EKS cluster API endpoint |
| cluster_certificate_authority_data | Cluster CA certificate |
| oidc_provider_arn | OIDC provider ARN for IRSA |
| aws_load_balancer_controller_role_arn | Load balancer controller IAM role |
| cluster_autoscaler_role_arn | Cluster autoscaler IAM role |
| kubectl_config | Configuration for kubectl |

## Add-ons

### Supported IRSA Roles
- **AWS Load Balancer Controller**: For ALB/NLB ingress
- **Cluster Autoscaler**: For node auto-scaling
- **EBS CSI Driver**: For persistent volume support
- **External Secrets Operator**: For secret management

### Managed Add-ons
- **CoreDNS**: DNS server for service discovery
- **kube-proxy**: Network proxy for services
- **VPC CNI**: AWS VPC networking for pods
- **EBS CSI Driver**: Persistent storage support

## Cost Optimization

### 1. **Spot Instances**
```hcl
managed_node_groups = {
  spot = {
    capacity_type = "SPOT"
    instance_types = ["m5.large", "m5a.large", "m4.large"]
  }
}
```

### 2. **Right-sizing**
```hcl
# Use appropriate instance types per workload
system_nodes = {
  instance_types = ["t3.medium"]  # For system workloads
}

workload_nodes = {
  instance_types = ["m5.large"]   # For applications
}
```

### 3. **Fargate for Bursty Workloads**
```hcl
fargate_profiles = {
  serverless = {
    selectors = [{
      namespace = "batch-jobs"
    }]
  }
}
```

## Troubleshooting

### Issue: Nodes not joining cluster
**Solution**: Verify IAM roles and subnet configurations
```bash
# Check node group status
aws eks describe-nodegroup --cluster-name my-cluster --nodegroup-name my-nodes

# Verify IAM role permissions
aws iam list-attached-role-policies --role-name my-cluster-node-group-role
```

### Issue: IRSA not working
**Solution**: Verify OIDC provider and trust relationships
```bash
# Check OIDC provider
aws iam list-open-id-connect-providers

# Verify service account annotation
kubectl describe serviceaccount my-sa -n my-namespace
```

### Issue: Private cluster access
**Solution**: Use bastion host or VPN for kubectl access
```bash
# Update kubeconfig
aws eks update-kubeconfig --name my-cluster --region us-east-1

# Test via bastion
ssh -i my-key.pem ec2-user@bastion-ip
kubectl get nodes
```

## References
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [EKS Security Best Practices](https://docs.aws.amazon.com/eks/latest/userguide/security.html)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)