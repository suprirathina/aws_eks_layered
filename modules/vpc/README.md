# Enterprise VPC Module

## Overview
This module creates a **secure, enterprise-grade VPC** designed for EKS workloads with multiple layers of security controls and cost optimization.

## Security Features

### 🔒 **Network Security**
- **Private-by-Default**: All workload subnets are private with no internet access
- **VPC Flow Logs**: Complete network traffic logging for security monitoring
- **Network ACLs**: Additional security layer beyond security groups
- **VPC Endpoints**: Private connectivity to AWS services (no internet required)

### 🛡️ **Defense in Depth**
- **Subnet Isolation**: Separate subnets for workloads, databases, and load balancers
- **Route Table Isolation**: Dedicated route tables per subnet tier
- **Security Group Ready**: Designed to work with least-privilege security groups
- **NAT Gateway Disabled**: By default, no internet access for cost and security

### 📊 **Monitoring & Compliance**
- **CloudWatch Integration**: VPC Flow Logs to CloudWatch
- **Cost Optimization**: Minimal public subnets, optional NAT gateways
- **Tagging Strategy**: Comprehensive tagging for cost allocation and governance

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        VPC (10.0.0.0/16)                   │
├─────────────────────────────────────────────────────────────┤
│  AZ-1a          │  AZ-1b          │  AZ-1c                │
├─────────────────┼─────────────────┼─────────────────────────┤
│ Private Subnet  │ Private Subnet  │ Private Subnet          │
│ 10.0.1.0/24     │ 10.0.2.0/24     │ 10.0.3.0/24            │
│ (EKS Nodes)     │ (EKS Nodes)     │ (EKS Nodes)            │
├─────────────────┼─────────────────┼─────────────────────────┤
│ Public Subnet   │ Public Subnet   │ Public Subnet           │
│ 10.0.101.0/24   │ 10.0.102.0/24   │ 10.0.103.0/24          │
│ (Load Balancers)│ (Load Balancers)│ (Load Balancers)       │
├─────────────────┼─────────────────┼─────────────────────────┤
│ Database Subnet │ Database Subnet │ Database Subnet         │
│ 10.0.201.0/24   │ 10.0.202.0/24   │ 10.0.203.0/24          │
│ (RDS/ElastiCache│ (RDS/ElastiCache│ (RDS/ElastiCache)      │
└─────────────────┴─────────────────┴─────────────────────────┘
                          │
                    ┌─────▼─────┐
                    │ VPC       │
                    │ Endpoints │
                    │ (Private) │
                    └───────────┘
```

## Usage

### Basic Usage
```hcl
module "vpc" {
  source = "../modules/vpc"
  
  environment  = "dev"
  cluster_name = "my-eks-cluster"
  vpc_cidr     = "10.0.0.0/16"
  
  tags = {
    Project = "my-project"
    Owner   = "platform-team"
  }
}
```

### Production Configuration
```hcl
module "vpc" {
  source = "../modules/vpc"
  
  environment  = "prod"
  cluster_name = "production-eks"
  vpc_cidr     = "10.0.0.0/16"
  
  # Security hardening
  enable_flow_logs      = true
  enable_network_acls   = true
  enable_vpc_endpoints  = true
  
  # Cost optimization
  enable_nat_gateway    = false  # Use VPC endpoints instead
  
  # Database isolation
  enable_database_subnets = true
  
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
module "vpc_dev" {
  source = "../modules/vpc"
  
  environment = "dev"
  cluster_name = "dev-eks"
  vpc_cidr = "10.1.0.0/16"
  
  # Dev-specific settings
  enable_nat_gateway = true  # Allow internet for development
  flow_log_retention_days = 7  # Shorter retention
}

# Production Environment  
module "vpc_prod" {
  source = "../modules/vpc"
  
  environment = "prod"
  cluster_name = "prod-eks" 
  vpc_cidr = "10.0.0.0/16"
  
  # Production security
  enable_nat_gateway = false  # No internet access
  flow_log_retention_days = 90  # Extended retention
  enable_network_acls = true  # Additional security
}
```

## Security Best Practices

### 1. **Network Isolation**
```hcl
# Private subnets have NO route to internet gateway
# All AWS service access via VPC endpoints
enable_vpc_endpoints = true
enable_nat_gateway = false  # Recommended for production
```

### 2. **Monitoring & Logging**
```hcl
# Enable comprehensive logging
enable_flow_logs = true
flow_log_retention_days = 30  # Adjust based on compliance requirements
```

### 3. **Defense in Depth**
```hcl
# Multiple security layers
enable_network_acls = true  # Layer 4 security
# Security groups provide layer 7 security (managed by EKS module)
```

## VPC Endpoints

The module creates VPC endpoints for common AWS services to eliminate internet dependency:

### Gateway Endpoints (No Cost)
- **S3**: Container image storage, application data

### Interface Endpoints (Minimal Cost)
- **ECR**: Container image registry
- **EC2**: Instance metadata and API calls
- **CloudWatch Logs**: Application logging
- **STS**: IAM token exchange
- **KMS**: Encryption key management
- **Secrets Manager**: Secret retrieval
- **Systems Manager**: Bastion host connectivity

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vpc_cidr | CIDR block for VPC | `string` | `"10.0.0.0/16"` | no |
| environment | Environment name (dev/staging/prod) | `string` | n/a | yes |
| cluster_name | EKS cluster name for tagging | `string` | n/a | yes |
| enable_nat_gateway | Enable NAT gateway (disabled for security) | `bool` | `false` | no |
| enable_flow_logs | Enable VPC Flow Logs | `bool` | `true` | no |
| enable_network_acls | Enable Network ACLs | `bool` | `true` | no |
| enable_vpc_endpoints | Enable VPC endpoints | `bool` | `true` | no |
| tags | Additional resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| vpc_cidr_block | VPC CIDR block |
| private_subnet_ids | Private subnet IDs |
| public_subnet_ids | Public subnet IDs (if enabled) |
| database_subnet_ids | Database subnet IDs (if enabled) |
| vpc_endpoints | Map of created VPC endpoints |

## Cost Optimization

### 1. **NAT Gateway Elimination**
- **Default**: NAT Gateway disabled (`enable_nat_gateway = false`)
- **Savings**: ~$45/month per NAT Gateway + data transfer costs
- **Alternative**: VPC endpoints for AWS service access

### 2. **Minimal Public Subnets**  
- Only created when `enable_public_subnets = true`
- Used only for load balancers, not compute resources

### 3. **Right-sized VPC Endpoints**
- Only creates endpoints for services actually used
- Configurable via `vpc_endpoints` variable

## Security Compliance

### SOC 2 Alignment
- ✅ **Access Controls**: Private subnets, security groups, NACLs
- ✅ **Monitoring**: VPC Flow Logs, CloudWatch integration  
- ✅ **Network Security**: VPC endpoints, no direct internet access

### PCI DSS Alignment
- ✅ **Network Segmentation**: Separate subnets by function
- ✅ **Access Restriction**: Private networks only
- ✅ **Monitoring**: Comprehensive logging enabled

### HIPAA Alignment  
- ✅ **Encryption in Transit**: VPC endpoints use TLS
- ✅ **Access Controls**: Multi-layer security approach
- ✅ **Audit Trails**: VPC Flow Logs for all network traffic

## Troubleshooting

### Issue: EKS nodes can't pull container images
**Solution**: Ensure VPC endpoints are enabled for ECR
```hcl
enable_vpc_endpoints = true
vpc_endpoints = ["ecr.api", "ecr.dkr", "s3"]
```

### Issue: High data transfer costs
**Solution**: Disable NAT gateway and use VPC endpoints
```hcl
enable_nat_gateway = false
enable_vpc_endpoints = true
```

### Issue: Applications can't reach AWS services
**Solution**: Verify VPC endpoint configuration
```bash
# Check endpoint status
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=vpc-xxxxx"
```

## References
- [AWS VPC Security Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [VPC Endpoints Documentation](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [EKS VPC Considerations](https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html)