# Enterprise Platform Module - Kubernetes Platform Services
# AWS Load Balancer Controller, Cluster Autoscaler, Service Mesh, and essential platform services

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
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  # Common tags for all resources
  common_tags = merge(
    var.tags,
    {
      Module      = "platform"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )

  # Account information
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  partition  = data.aws_partition.current.partition
}

# Kubernetes Namespaces for Platform Services
resource "kubernetes_namespace" "platform_namespaces" {
  for_each = var.platform_namespaces

  metadata {
    name = each.key
    
    labels = merge(
      each.value.labels,
      {
        "name"                          = each.key
        "app.kubernetes.io/managed-by" = "terraform"
        "platform/namespace-type"      = each.value.type
      }
    )
    
    annotations = each.value.annotations
  }

  timeouts {
    delete = "15m"
  }
}

# AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.aws_load_balancer_controller_version

  values = [
    yamlencode({
      clusterName = var.cluster_name
      
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = var.aws_load_balancer_controller_role_arn
        }
      }
      
      region = local.region
      vpcId  = var.vpc_id
      
      # Security configuration
      enableShield      = var.enable_aws_shield
      enableWAF         = var.enable_aws_waf
      enableWAFv2       = var.enable_aws_wafv2
      
      # Performance settings
      webhookTLS = {
        caCert = ""
        cert   = ""
        key    = ""
      }
      
      # Logging
      logLevel = var.alb_controller_log_level
      
      # Resource limits
      resources = var.alb_controller_resources
      
      # Node selector and tolerations
      nodeSelector = var.alb_controller_node_selector
      tolerations  = var.alb_controller_tolerations
      
      # Pod disruption budget
      podDisruptionBudget = {
        maxUnavailable = 1
      }
      
      # Additional configuration
      env = merge(
        {
          AWS_DEFAULT_REGION = local.region
        },
        var.alb_controller_env_vars
      )
    })
  ]

  depends_on = [kubernetes_namespace.platform_namespaces]
}

# Cluster Autoscaler
resource "helm_release" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = var.cluster_autoscaler_version

  values = [
    yamlencode({
      autoDiscovery = {
        clusterName = var.cluster_name
        enabled     = true
      }
      
      awsRegion = local.region
      
      serviceAccount = {
        create = true
        name   = "cluster-autoscaler"
        annotations = {
          "eks.amazonaws.com/role-arn" = var.cluster_autoscaler_role_arn
        }
      }
      
      # Autoscaler configuration
      extraArgs = merge(
        {
          "v"                                   = var.cluster_autoscaler_log_level
          "stderrthreshold"                     = "info"
          "cloud-provider"                      = "aws"
          "skip-nodes-with-local-storage"       = "false"
          "expander"                           = var.cluster_autoscaler_expander
          "node-group-auto-discovery"          = "asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/${var.cluster_name}"
          "balance-similar-node-groups"        = var.cluster_autoscaler_balance_similar_node_groups
          "scale-down-enabled"                 = var.cluster_autoscaler_scale_down_enabled
          "scale-down-delay-after-add"         = var.cluster_autoscaler_scale_down_delay_after_add
          "scale-down-unneeded-time"           = var.cluster_autoscaler_scale_down_unneeded_time
          "scale-down-utilization-threshold"   = var.cluster_autoscaler_scale_down_utilization_threshold
          "skip-nodes-with-system-pods"        = "false"
        },
        var.cluster_autoscaler_extra_args
      )
      
      # Resource limits
      resources = var.cluster_autoscaler_resources
      
      # Node selector and tolerations
      nodeSelector = var.cluster_autoscaler_node_selector
      tolerations  = var.cluster_autoscaler_tolerations
      
      # Pod disruption budget
      podDisruptionBudget = {
        maxUnavailable = 1
      }
      
      # Priority class
      priorityClassName = var.cluster_autoscaler_priority_class
    })
  ]

  depends_on = [kubernetes_namespace.platform_namespaces]
}

# Metrics Server (if not already installed)
resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = var.metrics_server_version

  values = [
    yamlencode({
      args = [
        "--cert-dir=/tmp",
        "--secure-port=4443",
        "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
        "--kubelet-use-node-status-port",
        "--metric-resolution=15s"
      ]
      
      resources = var.metrics_server_resources
      
      nodeSelector = var.metrics_server_node_selector
      tolerations  = var.metrics_server_tolerations
      
      # Security context
      securityContext = {
        allowPrivilegeEscalation = false
        readOnlyRootFilesystem   = true
        runAsNonRoot            = true
        runAsUser               = 1000
        capabilities = {
          drop = ["ALL"]
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.platform_namespaces]
}

# External DNS
resource "helm_release" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = var.external_dns_version

  values = [
    yamlencode({
      provider = "aws"
      
      aws = {
        region = local.region
        zoneType = var.external_dns_zone_type
      }
      
      serviceAccount = {
        create = true
        name   = "external-dns"
        annotations = {
          "eks.amazonaws.com/role-arn" = var.external_dns_role_arn
        }
      }
      
      # DNS configuration
      domainFilters = var.external_dns_domain_filters
      zoneIdFilters = var.external_dns_zone_id_filters
      
      txtOwnerId = var.cluster_name
      txtPrefix  = "eks-"
      
      # Security and performance
      policy     = var.external_dns_policy
      registry   = "txt"
      interval   = var.external_dns_sync_interval
      logLevel   = var.external_dns_log_level
      
      # Resource limits
      resources = var.external_dns_resources
      
      # Node selector and tolerations
      nodeSelector = var.external_dns_node_selector
      tolerations  = var.external_dns_tolerations
    })
  ]

  depends_on = [kubernetes_namespace.platform_namespaces]
}

# Cert Manager
resource "helm_release" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  version    = var.cert_manager_version

  values = [
    yamlencode({
      installCRDs = true
      
      serviceAccount = {
        create = true
        name   = "cert-manager"
        annotations = {
          "eks.amazonaws.com/role-arn" = var.cert_manager_role_arn
        }
      }
      
      # Security context
      securityContext = {
        fsGroup = 1001
      }
      
      # Global configuration
      global = {
        rbac = {
          create = true
        }
        
        podSecurityPolicy = {
          enabled = false
        }
        
        logLevel = var.cert_manager_log_level
      }
      
      # Controller configuration
      controller = {
        resources = var.cert_manager_resources
        
        nodeSelector = var.cert_manager_node_selector
        tolerations  = var.cert_manager_tolerations
        
        # Feature gates
        featureGates = var.cert_manager_feature_gates
      }
      
      # Webhook configuration
      webhook = {
        resources = var.cert_manager_webhook_resources
        
        securityContext = {
          runAsNonRoot = true
        }
      }
      
      # CA Injector configuration
      cainjector = {
        resources = var.cert_manager_cainjector_resources
        
        securityContext = {
          runAsNonRoot = true
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.platform_namespaces]
}

# Istio Service Mesh (if enabled)
resource "helm_release" "istio_base" {
  count = var.enable_istio ? 1 : 0

  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  namespace  = "istio-system"
  version    = var.istio_version

  create_namespace = true

  values = [
    yamlencode({
      global = {
        istioNamespace = "istio-system"
        meshID        = var.cluster_name
        network       = var.cluster_name
      }
    })
  ]

  depends_on = [kubernetes_namespace.platform_namespaces]
}

resource "helm_release" "istio_istiod" {
  count = var.enable_istio ? 1 : 0

  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  namespace  = "istio-system"
  version    = var.istio_version

  values = [
    yamlencode({
      global = {
        meshID  = var.cluster_name
        network = var.cluster_name
      }
      
      pilot = {
        resources = var.istio_pilot_resources
        
        env = {
          EXTERNAL_ISTIOD = false
          PILOT_TRACE_SAMPLING = var.istio_trace_sampling
        }
        
        nodeSelector = var.istio_node_selector
        tolerations  = var.istio_tolerations
      }
      
      # Telemetry configuration
      telemetry = {
        v2 = {
          enabled = true
          prometheus = {
            configOverride = {
              metric_relabeling_configs = var.istio_prometheus_config
            }
          }
        }
      }
    })
  ]

  depends_on = [helm_release.istio_base]
}

resource "helm_release" "istio_gateway" {
  count = var.enable_istio && var.enable_istio_gateway ? 1 : 0

  name       = "istio-gateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  namespace  = "istio-ingress"
  version    = var.istio_version

  create_namespace = true

  values = [
    yamlencode({
      service = {
        type = "LoadBalancer"
        annotations = var.istio_gateway_service_annotations
      }
      
      resources = var.istio_gateway_resources
      
      nodeSelector = var.istio_gateway_node_selector
      tolerations  = var.istio_gateway_tolerations
      
      # Autoscaling
      autoscaling = {
        enabled                        = var.istio_gateway_autoscaling_enabled
        minReplicas                    = var.istio_gateway_min_replicas
        maxReplicas                    = var.istio_gateway_max_replicas
        targetCPUUtilizationPercentage = var.istio_gateway_cpu_target_utilization
      }
    })
  ]

  depends_on = [helm_release.istio_istiod]
}

# NGINX Ingress Controller (alternative to Istio Gateway)
resource "helm_release" "nginx_ingress" {
  count = var.enable_nginx_ingress ? 1 : 0

  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  version    = var.nginx_ingress_version

  create_namespace = true

  values = [
    yamlencode({
      controller = {
        service = {
          type = "LoadBalancer"
          annotations = merge(
            {
              "service.beta.kubernetes.io/aws-load-balancer-type"                    = "nlb"
              "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
              "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"       = "tcp"
            },
            var.nginx_ingress_service_annotations
          )
        }
        
        resources = var.nginx_ingress_resources
        
        nodeSelector = var.nginx_ingress_node_selector
        tolerations  = var.nginx_ingress_tolerations
        
        # Configuration
        config = merge(
          {
            "use-proxy-protocol"           = "true"
            "compute-full-forwarded-for"   = "true"
            "use-forwarded-headers"        = "true"
            "proxy-real-ip-cidr"          = var.vpc_cidr
            "ssl-protocols"               = "TLSv1.2 TLSv1.3"
            "ssl-redirect"                = "true"
            "force-ssl-redirect"          = "true"
          },
          var.nginx_ingress_config
        )
        
        # Metrics
        metrics = {
          enabled = var.nginx_ingress_metrics_enabled
          
          serviceMonitor = {
            enabled = var.nginx_ingress_metrics_enabled && var.enable_prometheus_monitoring
          }
        }
        
        # Autoscaling
        autoscaling = {
          enabled                        = var.nginx_ingress_autoscaling_enabled
          minReplicas                    = var.nginx_ingress_min_replicas
          maxReplicas                    = var.nginx_ingress_max_replicas
          targetCPUUtilizationPercentage = var.nginx_ingress_cpu_target_utilization
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.platform_namespaces]
}

# Karpenter (Advanced Node Autoscaling)
resource "helm_release" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  namespace  = "karpenter"
  version    = var.karpenter_version

  create_namespace = true

  values = [
    yamlencode({
      settings = {
        aws = {
          clusterName     = var.cluster_name
          defaultInstanceProfile = var.karpenter_node_instance_profile
          region          = local.region
        }
        
        # Feature flags
        featureGates = {
          driftEnabled = var.karpenter_drift_enabled
        }
      }
      
      serviceAccount = {
        create = true
        name   = "karpenter"
        annotations = {
          "eks.amazonaws.com/role-arn" = var.karpenter_role_arn
        }
      }
      
      # Controller configuration
      controller = {
        resources = var.karpenter_resources
        
        nodeSelector = var.karpenter_node_selector
        tolerations  = var.karpenter_tolerations
        
        # Metrics
        metrics = {
          port = 8080
        }
      }
      
      # Webhook configuration
      webhook = {
        enabled = true
        port    = 8443
      }
    })
  ]

  depends_on = [kubernetes_namespace.platform_namespaces]
}

# ArgoCD (GitOps)
resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  version    = var.argocd_version

  create_namespace = true

  values = [
    yamlencode({
      global = {
        domain = var.argocd_domain
      }
      
      # Controller configuration
      controller = {
        resources = var.argocd_controller_resources
        
        nodeSelector = var.argocd_node_selector
        tolerations  = var.argocd_tolerations
      }
      
      # Server configuration
      server = {
        resources = var.argocd_server_resources
        
        service = {
          type = var.argocd_service_type
          annotations = var.argocd_service_annotations
        }
        
        ingress = {
          enabled = var.argocd_ingress_enabled
          annotations = var.argocd_ingress_annotations
          hosts = [var.argocd_domain]
          tls = var.argocd_ingress_tls
        }
        
        # RBAC configuration
        rbacConfig = var.argocd_rbac_config
        
        # Additional configuration
        config = merge(
          {
            "application.instanceLabelKey" = "argocd.argoproj.io/instance"
            "server.rbac.log.enforce.enable" = "true"
            "exec.enabled" = "false"
            "admin.enabled" = "true"
            "timeout.reconciliation" = "180s"
          },
          var.argocd_server_config
        )
      }
      
      # Repository server
      repoServer = {
        resources = var.argocd_repo_server_resources
        
        nodeSelector = var.argocd_node_selector
        tolerations  = var.argocd_tolerations
      }
      
      # Redis
      redis = {
        resources = var.argocd_redis_resources
        
        nodeSelector = var.argocd_node_selector
        tolerations  = var.argocd_tolerations
      }
    })
  ]

  depends_on = [kubernetes_namespace.platform_namespaces]
}