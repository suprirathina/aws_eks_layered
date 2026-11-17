# Enterprise Platform Module

Enterprise-grade Kubernetes platform services module providing essential infrastructure services for EKS clusters including ingress controllers, autoscaling, service mesh, and GitOps capabilities.

## 🏗️ **Architecture Overview**

This module deploys and manages critical Kubernetes platform services that applications depend on:

### **Core Platform Services**
- **AWS Load Balancer Controller** - Native AWS ALB/NLB integration
- **Cluster Autoscaler** - Automatic node scaling based on pod demands
- **Metrics Server** - Resource usage metrics for HPA and VPA
- **External DNS** - Automatic DNS record management
- **Cert Manager** - Automatic TLS certificate provisioning

### **Advanced Platform Services**
- **Istio Service Mesh** - Traffic management, security, and observability
- **NGINX Ingress Controller** - Alternative ingress solution
- **Karpenter** - Advanced node lifecycle management
- **ArgoCD** - GitOps continuous deployment

### **Enterprise Features**
- ✅ **IRSA Integration** - Service accounts with least-privilege IAM roles
- ✅ **Resource Management** - CPU/memory limits and requests
- ✅ **High Availability** - Pod disruption budgets and anti-affinity
- ✅ **Security Controls** - Non-root containers, read-only filesystems
- ✅ **Monitoring Integration** - Prometheus metrics and ServiceMonitors
- ✅ **Autoscaling** - HPA configuration for critical services

## 📋 **Prerequisites**

- EKS cluster with OIDC provider configured
- VPC with appropriate subnets and routing
- IAM roles for service accounts (IRSA) capability
- Helm 3.x installed and configured
- Route53 hosted zones (if using External DNS)

## 🚀 **Quick Start**

### **Basic Configuration**

```hcl
module "platform" {
  source = "./modules/platform"

  # Core configuration
  environment  = "production"
  cluster_name = "my-eks-cluster"
  vpc_id       = "vpc-12345678"
  vpc_cidr     = "10.0.0.0/16"

  # OIDC provider for IRSA
  oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.region.amazonaws.com/id/EXAMPLE"
  oidc_issuer_url   = "oidc.eks.region.amazonaws.com/id/EXAMPLE"

  # Required IAM role ARNs (from EKS module)
  aws_load_balancer_controller_role_arn = module.eks.aws_load_balancer_controller_role_arn
  cluster_autoscaler_role_arn          = module.eks.cluster_autoscaler_role_arn

  # Enable essential services
  enable_aws_load_balancer_controller = true
  enable_cluster_autoscaler           = true
  enable_metrics_server               = true

  tags = {
    Environment = "production"
    Project     = "enterprise-platform"
  }
}
```

### **Full Enterprise Configuration**

```hcl
module "platform" {
  source = "./modules/platform"

  # Core configuration
  environment  = "production"
  cluster_name = "enterprise-eks"
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = module.vpc.vpc_cidr

  # OIDC provider
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.oidc_issuer_url

  # IAM role ARNs
  aws_load_balancer_controller_role_arn = module.eks.aws_load_balancer_controller_role_arn
  cluster_autoscaler_role_arn          = module.eks.cluster_autoscaler_role_arn

  # Enable all platform services
  enable_aws_load_balancer_controller = true
  enable_cluster_autoscaler           = true
  enable_metrics_server               = true
  enable_external_dns                 = true
  enable_cert_manager                 = true
  enable_istio                        = true
  enable_nginx_ingress                = false  # Use either Istio or NGINX
  enable_karpenter                    = true
  enable_argocd                       = true

  # External DNS configuration
  external_dns_domain_filters    = ["example.com"]
  external_dns_zone_id_filters   = ["Z123456789"]
  external_dns_zone_type         = "public"

  # ArgoCD configuration
  argocd_domain               = "argocd.example.com"
  argocd_ingress_enabled      = true
  argocd_enable_aws_access    = true

  # Istio configuration
  enable_istio_gateway        = true
  istio_trace_sampling        = 1.0

  # Resource optimization
  alb_controller_resources = {
    limits = {
      cpu    = "200m"
      memory = "500Mi"
    }
    requests = {
      cpu    = "100m"
      memory = "200Mi"
    }
  }

  tags = {
    Environment = "production"
    Project     = "enterprise-platform"
    Owner       = "platform-team"
  }
}
```

## 🔧 **Service Configuration**

### **AWS Load Balancer Controller**

Automatically provisions ALB and NLB load balancers for Kubernetes ingress and services.

```hcl
# Enable with security features
enable_aws_load_balancer_controller = true
enable_aws_wafv2                    = true
enable_aws_shield                   = true

# Resource configuration
alb_controller_resources = {
  limits = {
    cpu    = "200m"
    memory = "500Mi"
  }
  requests = {
    cpu    = "100m"
    memory = "200Mi"
  }
}
```

### **Cluster Autoscaler**

Automatically adjusts cluster size based on pod scheduling requirements.

```hcl
enable_cluster_autoscaler = true

# Scaling configuration
cluster_autoscaler_expander                        = "least-waste"
cluster_autoscaler_scale_down_enabled              = true
cluster_autoscaler_scale_down_delay_after_add      = "10m"
cluster_autoscaler_scale_down_unneeded_time        = "10m"
cluster_autoscaler_scale_down_utilization_threshold = 0.5
```

### **External DNS**

Automatically creates DNS records for Kubernetes ingress and services.

```hcl
enable_external_dns = true

# DNS configuration
external_dns_domain_filters  = ["example.com", "internal.example.com"]
external_dns_zone_id_filters = ["Z123456789", "Z987654321"]
external_dns_zone_type       = "public"
external_dns_policy          = "upsert-only"
```

### **Cert Manager**

Automatically provisions and renews TLS certificates from Let's Encrypt and other CAs.

```hcl
enable_cert_manager = true

# Feature configuration
cert_manager_feature_gates = "ExperimentalCertificateSigningRequestControllers=true"
```

### **Istio Service Mesh**

Provides traffic management, security policies, and observability for microservices.

```hcl
enable_istio         = true
enable_istio_gateway = true

# Observability configuration
istio_trace_sampling = 1.0  # 100% tracing for development

# Gateway configuration
istio_gateway_autoscaling_enabled        = true
istio_gateway_min_replicas              = 2
istio_gateway_max_replicas              = 10
istio_gateway_cpu_target_utilization    = 80
```

### **Karpenter**

Advanced node provisioning with just-in-time scaling and cost optimization.

```hcl
enable_karpenter = true

# Advanced features
karpenter_drift_enabled = true

# Instance profile (created by module)
karpenter_node_instance_profile = module.platform.karpenter_node_instance_profile
```

### **ArgoCD**

GitOps continuous deployment platform.

```hcl
enable_argocd = true

# Access configuration
argocd_domain          = "argocd.example.com"
argocd_ingress_enabled = true
argocd_service_type    = "ClusterIP"

# AWS integration
argocd_enable_aws_access     = true
argocd_codecommit_repositories = [
  "arn:aws:codecommit:us-east-1:123456789012:my-app-repo"
]
```

## 🔐 **Security Features**

### **IAM Integration**
- **IRSA (IAM Roles for Service Accounts)** for all services
- **Least privilege policies** with service-specific permissions
- **Cross-account access** support for multi-account architectures

### **Security Contexts**
- **Non-root containers** for enhanced security
- **Read-only root filesystems** where applicable
- **Security capabilities** dropped by default

### **Network Security**
- **Private container registries** integration
- **VPC endpoint** support for AWS services
- **Network policies** ready configuration

## 📊 **Monitoring and Observability**

### **Metrics Collection**
- **Prometheus metrics** exposed by all services
- **ServiceMonitor** CRDs for Prometheus Operator
- **Custom metrics** for autoscaling decisions

### **Logging Integration**
- **Structured logging** with consistent formats
- **Log aggregation** ready configuration
- **Audit trails** for security compliance

### **Alerting**
- **Resource utilization** alerts
- **Service health** monitoring
- **Error rate** tracking

## 🏢 **Enterprise Patterns**

### **Multi-Environment Support**

```hcl
# Development environment
module "platform_dev" {
  source = "./modules/platform"
  
  environment = "dev"
  
  # Reduced resource limits
  alb_controller_resources = {
    limits = {
      cpu    = "100m"
      memory = "256Mi"
    }
    requests = {
      cpu    = "50m"
      memory = "128Mi"
    }
  }
}

# Production environment
module "platform_prod" {
  source = "./modules/platform"
  
  environment = "prod"
  
  # Enhanced resource limits
  alb_controller_resources = {
    limits = {
      cpu    = "500m"
      memory = "1Gi"
    }
    requests = {
      cpu    = "200m"
      memory = "500Mi"
    }
  }
}
```

### **Service Mesh Adoption**

```hcl
# Phase 1: Traditional ingress
enable_nginx_ingress = true
enable_istio        = false

# Phase 2: Gradual migration
enable_nginx_ingress = true
enable_istio        = true
enable_istio_gateway = false

# Phase 3: Full service mesh
enable_nginx_ingress = false
enable_istio        = true
enable_istio_gateway = true
```

## 📈 **Scaling and Performance**

### **Horizontal Pod Autoscaling**
- **CPU and memory** based scaling
- **Custom metrics** support
- **Predictive scaling** capabilities

### **Vertical Pod Autoscaling**
- **Resource recommendation** engine
- **Automatic resource** adjustment
- **Historical usage** analysis

### **Cluster Autoscaling**
- **Multi-AZ node distribution**
- **Spot instance** integration
- **Cost optimization** algorithms

## 🔄 **GitOps Integration**

### **ArgoCD Applications**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-services
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/company/k8s-manifests
    targetRevision: HEAD
    path: platform/production
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### **Configuration Management**
- **Helm value overrides** per environment
- **Kustomize patches** for customization
- **Secret management** with External Secrets

## 🛡️ **Compliance and Governance**

### **Policy Enforcement**
- **Pod Security Standards** enforcement
- **Network policies** for traffic segmentation
- **Resource quotas** and limits

### **Audit and Compliance**
- **Admission controllers** for policy validation
- **Audit logging** for compliance requirements
- **Security scanning** integration

## 🚨 **Troubleshooting**

### **Common Issues**

#### **ALB Controller Not Creating Load Balancers**
```bash
# Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify IAM permissions
aws iam get-role --role-name <alb-controller-role-name>

# Check service account annotations
kubectl describe sa aws-load-balancer-controller -n kube-system
```

#### **Cluster Autoscaler Not Scaling**
```bash
# Check autoscaler logs
kubectl logs -n kube-system deployment/cluster-autoscaler

# Verify node group tags
aws eks describe-nodegroup --cluster-name <cluster-name> --nodegroup-name <nodegroup-name>

# Check pending pods
kubectl get pods --all-namespaces --field-selector=status.phase=Pending
```

#### **External DNS Not Creating Records**
```bash
# Check external-dns logs
kubectl logs -n kube-system deployment/external-dns

# Verify Route53 permissions
aws sts get-caller-identity

# Check ingress annotations
kubectl get ingress -A -o yaml
```

### **Health Checks**

```bash
# Check all platform services
kubectl get pods -n kube-system -l app.kubernetes.io/managed-by=Helm

# Verify service endpoints
kubectl get svc -A --show-labels

# Check resource usage
kubectl top nodes
kubectl top pods -A
```

## 📚 **Best Practices**

### **Resource Management**
- Set appropriate **resource requests and limits**
- Use **priority classes** for critical services
- Implement **pod disruption budgets**

### **Security**
- Regularly **update Helm charts** and container images
- Use **image scanning** in CI/CD pipelines
- Implement **least privilege** access controls

### **Monitoring**
- Set up **comprehensive alerting** rules
- Monitor **service level indicators** (SLIs)
- Track **error budgets** and SLOs

### **Operations**
- Automate **certificate renewal**
- Implement **chaos engineering** practices
- Regular **disaster recovery** testing

## 🏷️ **Tagging Strategy**

```hcl
tags = {
  Environment     = "production"
  Project         = "enterprise-platform"
  Owner          = "platform-team@company.com"
  CostCenter     = "engineering"
  Compliance     = "sox-compliant"
  BackupPolicy   = "daily"
  MonitoringTier = "critical"
}
```

## 📋 **Outputs Reference**

| Output | Description |
|--------|-------------|
| `platform_namespaces` | Map of created namespaces |
| `aws_load_balancer_controller` | ALB controller configuration |
| `cluster_autoscaler` | Autoscaler configuration |
| `external_dns_role_arn` | External DNS IAM role |
| `cert_manager_role_arn` | Cert Manager IAM role |
| `istio` | Service mesh configuration |
| `karpenter_node_instance_profile` | Karpenter node profile |
| `argocd` | GitOps configuration |
| `enabled_services` | Summary of enabled services |

---

**Note**: This module is designed for production use and includes enterprise-grade security, monitoring, and operational capabilities. Customize the configuration based on your specific requirements and compliance needs.