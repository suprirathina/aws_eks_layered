# Platform Module Variables - Kubernetes Platform Services Configuration

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# EKS Integration
variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider for IRSA"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL without https:// prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster is deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for network configuration"
  type        = string
}

# Platform Namespaces
variable "platform_namespaces" {
  description = "Kubernetes namespaces for platform services"
  type = map(object({
    type        = string
    labels      = optional(map(string), {})
    annotations = optional(map(string), {})
  }))
  default = {
    "kube-system" = {
      type = "system"
    }
    "cert-manager" = {
      type = "platform"
    }
    "ingress-nginx" = {
      type = "platform"
    }
    "istio-system" = {
      type = "service-mesh"
    }
    "istio-ingress" = {
      type = "service-mesh"
    }
    "karpenter" = {
      type = "autoscaling"
    }
    "argocd" = {
      type = "gitops"
    }
    "monitoring" = {
      type = "observability"
    }
  }
}

# AWS Load Balancer Controller
variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "aws_load_balancer_controller_version" {
  description = "AWS Load Balancer Controller Helm chart version"
  type        = string
  default     = "1.6.2"
}

variable "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  type        = string
}

variable "enable_aws_shield" {
  description = "Enable AWS Shield Advanced integration"
  type        = bool
  default     = false
}

variable "enable_aws_waf" {
  description = "Enable AWS WAF integration"
  type        = bool
  default     = false
}

variable "enable_aws_wafv2" {
  description = "Enable AWS WAFv2 integration"
  type        = bool
  default     = true
}

variable "alb_controller_log_level" {
  description = "Log level for ALB controller"
  type        = string
  default     = "info"
  
  validation {
    condition = contains(["debug", "info", "warn", "error"], var.alb_controller_log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}

variable "alb_controller_resources" {
  description = "Resource limits for ALB controller"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "200m"
      memory = "500Mi"
    }
    requests = {
      cpu    = "100m"
      memory = "200Mi"
    }
  }
}

variable "alb_controller_node_selector" {
  description = "Node selector for ALB controller"
  type        = map(string)
  default     = {}
}

variable "alb_controller_tolerations" {
  description = "Tolerations for ALB controller"
  type        = list(any)
  default     = []
}

variable "alb_controller_env_vars" {
  description = "Environment variables for ALB controller"
  type        = map(string)
  default     = {}
}

# Cluster Autoscaler
variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "cluster_autoscaler_version" {
  description = "Cluster Autoscaler Helm chart version"
  type        = string
  default     = "9.29.0"
}

variable "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  type        = string
}

variable "cluster_autoscaler_log_level" {
  description = "Log verbosity level for Cluster Autoscaler"
  type        = number
  default     = 2
}

variable "cluster_autoscaler_expander" {
  description = "Cluster Autoscaler expander strategy"
  type        = string
  default     = "least-waste"
  
  validation {
    condition = contains(["random", "most-pods", "least-waste", "spot-price", "priority"], var.cluster_autoscaler_expander)
    error_message = "Expander must be one of: random, most-pods, least-waste, spot-price, priority."
  }
}

variable "cluster_autoscaler_balance_similar_node_groups" {
  description = "Balance similar node groups"
  type        = bool
  default     = false
}

variable "cluster_autoscaler_scale_down_enabled" {
  description = "Enable scale down"
  type        = bool
  default     = true
}

variable "cluster_autoscaler_scale_down_delay_after_add" {
  description = "Scale down delay after node add"
  type        = string
  default     = "10m"
}

variable "cluster_autoscaler_scale_down_unneeded_time" {
  description = "Scale down unneeded time"
  type        = string
  default     = "10m"
}

variable "cluster_autoscaler_scale_down_utilization_threshold" {
  description = "Scale down utilization threshold"
  type        = number
  default     = 0.5
}

variable "cluster_autoscaler_resources" {
  description = "Resource limits for Cluster Autoscaler"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "100m"
      memory = "300Mi"
    }
    requests = {
      cpu    = "100m"
      memory = "300Mi"
    }
  }
}

variable "cluster_autoscaler_node_selector" {
  description = "Node selector for Cluster Autoscaler"
  type        = map(string)
  default     = {}
}

variable "cluster_autoscaler_tolerations" {
  description = "Tolerations for Cluster Autoscaler"
  type        = list(any)
  default     = []
}

variable "cluster_autoscaler_priority_class" {
  description = "Priority class for Cluster Autoscaler"
  type        = string
  default     = "system-cluster-critical"
}

variable "cluster_autoscaler_extra_args" {
  description = "Extra arguments for Cluster Autoscaler"
  type        = map(string)
  default     = {}
}

# Metrics Server
variable "enable_metrics_server" {
  description = "Enable Metrics Server"
  type        = bool
  default     = true
}

variable "metrics_server_version" {
  description = "Metrics Server Helm chart version"
  type        = string
  default     = "3.11.0"
}

variable "metrics_server_resources" {
  description = "Resource limits for Metrics Server"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "100m"
      memory = "200Mi"
    }
    requests = {
      cpu    = "100m"
      memory = "200Mi"
    }
  }
}

variable "metrics_server_node_selector" {
  description = "Node selector for Metrics Server"
  type        = map(string)
  default     = {}
}

variable "metrics_server_tolerations" {
  description = "Tolerations for Metrics Server"
  type        = list(any)
  default     = []
}

# External DNS
variable "enable_external_dns" {
  description = "Enable External DNS"
  type        = bool
  default     = false
}

variable "external_dns_version" {
  description = "External DNS Helm chart version"
  type        = string
  default     = "1.13.1"
}

variable "external_dns_role_arn" {
  description = "IAM role ARN for External DNS"
  type        = string
  default     = ""
}

variable "external_dns_zone_type" {
  description = "Route53 zone type (public or private)"
  type        = string
  default     = "public"
  
  validation {
    condition = contains(["public", "private"], var.external_dns_zone_type)
    error_message = "Zone type must be either 'public' or 'private'."
  }
}

variable "external_dns_domain_filters" {
  description = "Domain filters for External DNS"
  type        = list(string)
  default     = []
}

variable "external_dns_zone_id_filters" {
  description = "Zone ID filters for External DNS"
  type        = list(string)
  default     = []
}

variable "external_dns_policy" {
  description = "External DNS policy (sync or upsert-only)"
  type        = string
  default     = "upsert-only"
  
  validation {
    condition = contains(["sync", "upsert-only"], var.external_dns_policy)
    error_message = "Policy must be either 'sync' or 'upsert-only'."
  }
}

variable "external_dns_sync_interval" {
  description = "External DNS sync interval"
  type        = string
  default     = "1m"
}

variable "external_dns_log_level" {
  description = "External DNS log level"
  type        = string
  default     = "info"
}

variable "external_dns_resources" {
  description = "Resource limits for External DNS"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "50m"
      memory = "50Mi"
    }
    requests = {
      cpu    = "10m"
      memory = "50Mi"
    }
  }
}

variable "external_dns_node_selector" {
  description = "Node selector for External DNS"
  type        = map(string)
  default     = {}
}

variable "external_dns_tolerations" {
  description = "Tolerations for External DNS"
  type        = list(any)
  default     = []
}

# Cert Manager
variable "enable_cert_manager" {
  description = "Enable Cert Manager"
  type        = bool
  default     = false
}

variable "cert_manager_version" {
  description = "Cert Manager Helm chart version"
  type        = string
  default     = "v1.13.1"
}

variable "cert_manager_role_arn" {
  description = "IAM role ARN for Cert Manager"
  type        = string
  default     = ""
}

variable "cert_manager_log_level" {
  description = "Cert Manager log level"
  type        = number
  default     = 2
}

variable "cert_manager_resources" {
  description = "Resource limits for Cert Manager controller"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "100m"
      memory = "128Mi"
    }
    requests = {
      cpu    = "10m"
      memory = "32Mi"
    }
  }
}

variable "cert_manager_webhook_resources" {
  description = "Resource limits for Cert Manager webhook"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "100m"
      memory = "128Mi"
    }
    requests = {
      cpu    = "10m"
      memory = "32Mi"
    }
  }
}

variable "cert_manager_cainjector_resources" {
  description = "Resource limits for Cert Manager cainjector"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "100m"
      memory = "128Mi"
    }
    requests = {
      cpu    = "10m"
      memory = "32Mi"
    }
  }
}

variable "cert_manager_node_selector" {
  description = "Node selector for Cert Manager"
  type        = map(string)
  default     = {}
}

variable "cert_manager_tolerations" {
  description = "Tolerations for Cert Manager"
  type        = list(any)
  default     = []
}

variable "cert_manager_feature_gates" {
  description = "Feature gates for Cert Manager"
  type        = string
  default     = ""
}

# Istio Service Mesh
variable "enable_istio" {
  description = "Enable Istio Service Mesh"
  type        = bool
  default     = false
}

variable "istio_version" {
  description = "Istio Helm chart version"
  type        = string
  default     = "1.19.3"
}

variable "enable_istio_gateway" {
  description = "Enable Istio Gateway"
  type        = bool
  default     = true
}

variable "istio_pilot_resources" {
  description = "Resource limits for Istio Pilot"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "500m"
      memory = "2048Mi"
    }
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
  }
}

variable "istio_gateway_resources" {
  description = "Resource limits for Istio Gateway"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "2000m"
      memory = "1024Mi"
    }
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
  }
}

variable "istio_trace_sampling" {
  description = "Istio trace sampling percentage"
  type        = number
  default     = 1.0
}

variable "istio_node_selector" {
  description = "Node selector for Istio components"
  type        = map(string)
  default     = {}
}

variable "istio_tolerations" {
  description = "Tolerations for Istio components"
  type        = list(any)
  default     = []
}

variable "istio_gateway_service_annotations" {
  description = "Service annotations for Istio Gateway"
  type        = map(string)
  default = {
    "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
  }
}

variable "istio_gateway_autoscaling_enabled" {
  description = "Enable autoscaling for Istio Gateway"
  type        = bool
  default     = true
}

variable "istio_gateway_min_replicas" {
  description = "Minimum replicas for Istio Gateway"
  type        = number
  default     = 2
}

variable "istio_gateway_max_replicas" {
  description = "Maximum replicas for Istio Gateway"
  type        = number
  default     = 10
}

variable "istio_gateway_cpu_target_utilization" {
  description = "CPU target utilization for Istio Gateway autoscaling"
  type        = number
  default     = 80
}

variable "istio_gateway_node_selector" {
  description = "Node selector for Istio Gateway"
  type        = map(string)
  default     = {}
}

variable "istio_gateway_tolerations" {
  description = "Tolerations for Istio Gateway"
  type        = list(any)
  default     = []
}

variable "istio_prometheus_config" {
  description = "Prometheus configuration for Istio telemetry"
  type        = list(any)
  default     = []
}

# NGINX Ingress Controller
variable "enable_nginx_ingress" {
  description = "Enable NGINX Ingress Controller"
  type        = bool
  default     = false
}

variable "nginx_ingress_version" {
  description = "NGINX Ingress Controller Helm chart version"
  type        = string
  default     = "4.8.3"
}

variable "nginx_ingress_service_annotations" {
  description = "Service annotations for NGINX Ingress"
  type        = map(string)
  default     = {}
}

variable "nginx_ingress_resources" {
  description = "Resource limits for NGINX Ingress"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "1000m"
      memory = "512Mi"
    }
    requests = {
      cpu    = "100m"
      memory = "90Mi"
    }
  }
}

variable "nginx_ingress_node_selector" {
  description = "Node selector for NGINX Ingress"
  type        = map(string)
  default     = {}
}

variable "nginx_ingress_tolerations" {
  description = "Tolerations for NGINX Ingress"
  type        = list(any)
  default     = []
}

variable "nginx_ingress_config" {
  description = "Configuration for NGINX Ingress"
  type        = map(string)
  default     = {}
}

variable "nginx_ingress_metrics_enabled" {
  description = "Enable metrics for NGINX Ingress"
  type        = bool
  default     = true
}

variable "nginx_ingress_autoscaling_enabled" {
  description = "Enable autoscaling for NGINX Ingress"
  type        = bool
  default     = true
}

variable "nginx_ingress_min_replicas" {
  description = "Minimum replicas for NGINX Ingress"
  type        = number
  default     = 2
}

variable "nginx_ingress_max_replicas" {
  description = "Maximum replicas for NGINX Ingress"
  type        = number
  default     = 10
}

variable "nginx_ingress_cpu_target_utilization" {
  description = "CPU target utilization for NGINX Ingress autoscaling"
  type        = number
  default     = 80
}

variable "nginx_ingress_enable_aws_load_balancer_controller_integration" {
  description = "Enable AWS Load Balancer Controller integration for NGINX Ingress"
  type        = bool
  default     = false
}

variable "enable_prometheus_monitoring" {
  description = "Enable Prometheus monitoring integration"
  type        = bool
  default     = true
}

# Karpenter
variable "enable_karpenter" {
  description = "Enable Karpenter for advanced node autoscaling"
  type        = bool
  default     = false
}

variable "karpenter_version" {
  description = "Karpenter Helm chart version"
  type        = string
  default     = "v0.31.0"
}

variable "karpenter_role_arn" {
  description = "IAM role ARN for Karpenter controller"
  type        = string
  default     = ""
}

variable "karpenter_node_instance_profile" {
  description = "Instance profile for Karpenter nodes"
  type        = string
  default     = ""
}

variable "karpenter_drift_enabled" {
  description = "Enable Karpenter drift detection"
  type        = bool
  default     = true
}

variable "karpenter_resources" {
  description = "Resource limits for Karpenter controller"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
    requests = {
      cpu    = "100m"
      memory = "100Mi"
    }
  }
}

variable "karpenter_node_selector" {
  description = "Node selector for Karpenter"
  type        = map(string)
  default     = {}
}

variable "karpenter_tolerations" {
  description = "Tolerations for Karpenter"
  type        = list(any)
  default     = []
}

# ArgoCD
variable "enable_argocd" {
  description = "Enable ArgoCD for GitOps"
  type        = bool
  default     = false
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.46.8"
}

variable "argocd_domain" {
  description = "Domain for ArgoCD server"
  type        = string
  default     = ""
}

variable "argocd_service_type" {
  description = "Service type for ArgoCD server"
  type        = string
  default     = "ClusterIP"
}

variable "argocd_service_annotations" {
  description = "Service annotations for ArgoCD server"
  type        = map(string)
  default     = {}
}

variable "argocd_ingress_enabled" {
  description = "Enable ingress for ArgoCD server"
  type        = bool
  default     = false
}

variable "argocd_ingress_annotations" {
  description = "Ingress annotations for ArgoCD server"
  type        = map(string)
  default     = {}
}

variable "argocd_ingress_tls" {
  description = "TLS configuration for ArgoCD ingress"
  type        = list(any)
  default     = []
}

variable "argocd_controller_resources" {
  description = "Resource limits for ArgoCD controller"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
    requests = {
      cpu    = "250m"
      memory = "256Mi"
    }
  }
}

variable "argocd_server_resources" {
  description = "Resource limits for ArgoCD server"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "100m"
      memory = "128Mi"
    }
    requests = {
      cpu    = "50m"
      memory = "64Mi"
    }
  }
}

variable "argocd_repo_server_resources" {
  description = "Resource limits for ArgoCD repository server"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "1000m"
      memory = "1024Mi"
    }
    requests = {
      cpu    = "10m"
      memory = "64Mi"
    }
  }
}

variable "argocd_redis_resources" {
  description = "Resource limits for ArgoCD Redis"
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits = {
      cpu    = "200m"
      memory = "128Mi"
    }
    requests = {
      cpu    = "100m"
      memory = "64Mi"
    }
  }
}

variable "argocd_node_selector" {
  description = "Node selector for ArgoCD components"
  type        = map(string)
  default     = {}
}

variable "argocd_tolerations" {
  description = "Tolerations for ArgoCD components"
  type        = list(any)
  default     = []
}

variable "argocd_rbac_config" {
  description = "RBAC configuration for ArgoCD"
  type        = map(string)
  default     = {}
}

variable "argocd_server_config" {
  description = "Additional server configuration for ArgoCD"
  type        = map(string)
  default     = {}
}

variable "argocd_enable_aws_access" {
  description = "Enable AWS access for ArgoCD (CodeCommit, ECR)"
  type        = bool
  default     = false
}

variable "argocd_codecommit_repositories" {
  description = "List of CodeCommit repository ARNs for ArgoCD access"
  type        = list(string)
  default     = []
}