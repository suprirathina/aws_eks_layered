# Platform Module Outputs - Kubernetes Platform Services

# Platform Namespaces
output "platform_namespaces" {
  description = "Map of platform namespaces created"
  value = {
    for k, v in kubernetes_namespace.platform_namespaces : k => {
      name = v.metadata[0].name
      type = var.platform_namespaces[k].type
    }
  }
}

# AWS Load Balancer Controller
output "aws_load_balancer_controller" {
  description = "AWS Load Balancer Controller configuration"
  value = var.enable_aws_load_balancer_controller ? {
    enabled         = true
    chart_version   = var.aws_load_balancer_controller_version
    namespace       = "kube-system"
    service_account = "aws-load-balancer-controller"
    role_arn        = var.aws_load_balancer_controller_role_arn
  } : null
}

# Cluster Autoscaler
output "cluster_autoscaler" {
  description = "Cluster Autoscaler configuration"
  value = var.enable_cluster_autoscaler ? {
    enabled         = true
    chart_version   = var.cluster_autoscaler_version
    namespace       = "kube-system"
    service_account = "cluster-autoscaler"
    role_arn        = var.cluster_autoscaler_role_arn
    expander        = var.cluster_autoscaler_expander
  } : null
}

# Metrics Server
output "metrics_server" {
  description = "Metrics Server configuration"
  value = var.enable_metrics_server ? {
    enabled       = true
    chart_version = var.metrics_server_version
    namespace     = "kube-system"
  } : null
}

# External DNS
output "external_dns" {
  description = "External DNS configuration and IAM role"
  value = var.enable_external_dns ? {
    enabled         = true
    chart_version   = var.external_dns_version
    namespace       = "kube-system"
    service_account = "external-dns"
    role_arn        = try(aws_iam_role.external_dns[0].arn, "")
    domain_filters  = var.external_dns_domain_filters
    zone_id_filters = var.external_dns_zone_id_filters
    zone_type       = var.external_dns_zone_type
  } : null
}

output "external_dns_role_arn" {
  description = "IAM role ARN for External DNS"
  value       = var.enable_external_dns ? aws_iam_role.external_dns[0].arn : null
}

# Cert Manager
output "cert_manager" {
  description = "Cert Manager configuration and IAM role"
  value = var.enable_cert_manager ? {
    enabled         = true
    chart_version   = var.cert_manager_version
    namespace       = "cert-manager"
    service_account = "cert-manager"
    role_arn        = try(aws_iam_role.cert_manager[0].arn, "")
  } : null
}

output "cert_manager_role_arn" {
  description = "IAM role ARN for Cert Manager"
  value       = var.enable_cert_manager ? aws_iam_role.cert_manager[0].arn : null
}

# Istio Service Mesh
output "istio" {
  description = "Istio Service Mesh configuration"
  value = var.enable_istio ? {
    enabled           = true
    chart_version     = var.istio_version
    base_namespace    = "istio-system"
    gateway_namespace = var.enable_istio_gateway ? "istio-ingress" : null
    gateway_enabled   = var.enable_istio_gateway
    trace_sampling    = var.istio_trace_sampling
  } : null
}

# NGINX Ingress Controller
output "nginx_ingress" {
  description = "NGINX Ingress Controller configuration and IAM role"
  value = var.enable_nginx_ingress ? {
    enabled         = true
    chart_version   = var.nginx_ingress_version
    namespace       = "ingress-nginx"
    service_account = "nginx-ingress-ingress-nginx-controller"
    role_arn        = var.nginx_ingress_enable_aws_load_balancer_controller_integration ? try(aws_iam_role.nginx_ingress[0].arn, "") : null
    metrics_enabled = var.nginx_ingress_metrics_enabled
  } : null
}

output "nginx_ingress_role_arn" {
  description = "IAM role ARN for NGINX Ingress Controller"
  value       = var.enable_nginx_ingress && var.nginx_ingress_enable_aws_load_balancer_controller_integration ? aws_iam_role.nginx_ingress[0].arn : null
}

# Karpenter
output "karpenter" {
  description = "Karpenter configuration and IAM roles"
  value = var.enable_karpenter ? {
    enabled                 = true
    chart_version          = var.karpenter_version
    namespace              = "karpenter"
    service_account        = "karpenter"
    controller_role_arn    = try(aws_iam_role.karpenter_controller[0].arn, "")
    node_role_arn         = try(aws_iam_role.karpenter_node[0].arn, "")
    node_instance_profile = try(aws_iam_instance_profile.karpenter_node[0].name, "")
    drift_enabled         = var.karpenter_drift_enabled
  } : null
}

output "karpenter_controller_role_arn" {
  description = "IAM role ARN for Karpenter controller"
  value       = var.enable_karpenter ? aws_iam_role.karpenter_controller[0].arn : null
}

output "karpenter_node_role_arn" {
  description = "IAM role ARN for Karpenter nodes"
  value       = var.enable_karpenter ? aws_iam_role.karpenter_node[0].arn : null
}

output "karpenter_node_instance_profile" {
  description = "Instance profile name for Karpenter nodes"
  value       = var.enable_karpenter ? aws_iam_instance_profile.karpenter_node[0].name : null
}

# ArgoCD
output "argocd" {
  description = "ArgoCD configuration and IAM role"
  value = var.enable_argocd ? {
    enabled         = true
    chart_version   = var.argocd_version
    namespace       = "argocd"
    service_account = "argocd-server"
    role_arn        = var.argocd_enable_aws_access ? try(aws_iam_role.argocd[0].arn, "") : null
    domain          = var.argocd_domain
    service_type    = var.argocd_service_type
    ingress_enabled = var.argocd_ingress_enabled
  } : null
}

output "argocd_role_arn" {
  description = "IAM role ARN for ArgoCD"
  value       = var.enable_argocd && var.argocd_enable_aws_access ? aws_iam_role.argocd[0].arn : null
}

# Platform Services Summary
output "enabled_services" {
  description = "Summary of enabled platform services"
  value = {
    aws_load_balancer_controller = var.enable_aws_load_balancer_controller
    cluster_autoscaler          = var.enable_cluster_autoscaler
    metrics_server              = var.enable_metrics_server
    external_dns                = var.enable_external_dns
    cert_manager                = var.enable_cert_manager
    istio                       = var.enable_istio
    nginx_ingress              = var.enable_nginx_ingress
    karpenter                  = var.enable_karpenter
    argocd                     = var.enable_argocd
  }
}

# Service Endpoints (when applicable)
output "service_endpoints" {
  description = "Service endpoints for platform services"
  value = {
    argocd_server = var.enable_argocd && var.argocd_domain != "" ? "https://${var.argocd_domain}" : null
    istio_gateway = var.enable_istio && var.enable_istio_gateway ? "Deployed in istio-ingress namespace" : null
    nginx_ingress = var.enable_nginx_ingress ? "Deployed in ingress-nginx namespace" : null
  }
}

# IAM Role ARNs (for use in other modules)
output "iam_role_arns" {
  description = "IAM role ARNs created by this module"
  value = {
    external_dns              = var.enable_external_dns ? aws_iam_role.external_dns[0].arn : null
    cert_manager             = var.enable_cert_manager ? aws_iam_role.cert_manager[0].arn : null
    karpenter_controller     = var.enable_karpenter ? aws_iam_role.karpenter_controller[0].arn : null
    karpenter_node          = var.enable_karpenter ? aws_iam_role.karpenter_node[0].arn : null
    nginx_ingress           = var.enable_nginx_ingress && var.nginx_ingress_enable_aws_load_balancer_controller_integration ? aws_iam_role.nginx_ingress[0].arn : null
    argocd                  = var.enable_argocd && var.argocd_enable_aws_access ? aws_iam_role.argocd[0].arn : null
  }
}

# Helm Release Status
output "helm_releases" {
  description = "Status of Helm releases deployed by this module"
  value = {
    aws_load_balancer_controller = var.enable_aws_load_balancer_controller ? {
      name      = "aws-load-balancer-controller"
      namespace = "kube-system"
      version   = var.aws_load_balancer_controller_version
      status    = try(helm_release.aws_load_balancer_controller[0].status, "unknown")
    } : null

    cluster_autoscaler = var.enable_cluster_autoscaler ? {
      name      = "cluster-autoscaler"
      namespace = "kube-system"
      version   = var.cluster_autoscaler_version
      status    = try(helm_release.cluster_autoscaler[0].status, "unknown")
    } : null

    metrics_server = var.enable_metrics_server ? {
      name      = "metrics-server"
      namespace = "kube-system"
      version   = var.metrics_server_version
      status    = try(helm_release.metrics_server[0].status, "unknown")
    } : null

    external_dns = var.enable_external_dns ? {
      name      = "external-dns"
      namespace = "kube-system"
      version   = var.external_dns_version
      status    = try(helm_release.external_dns[0].status, "unknown")
    } : null

    cert_manager = var.enable_cert_manager ? {
      name      = "cert-manager"
      namespace = "cert-manager"
      version   = var.cert_manager_version
      status    = try(helm_release.cert_manager[0].status, "unknown")
    } : null

    istio_base = var.enable_istio ? {
      name      = "istio-base"
      namespace = "istio-system"
      version   = var.istio_version
      status    = try(helm_release.istio_base[0].status, "unknown")
    } : null

    istio_istiod = var.enable_istio ? {
      name      = "istiod"
      namespace = "istio-system"
      version   = var.istio_version
      status    = try(helm_release.istio_istiod[0].status, "unknown")
    } : null

    istio_gateway = var.enable_istio && var.enable_istio_gateway ? {
      name      = "istio-gateway"
      namespace = "istio-ingress"
      version   = var.istio_version
      status    = try(helm_release.istio_gateway[0].status, "unknown")
    } : null

    nginx_ingress = var.enable_nginx_ingress ? {
      name      = "nginx-ingress"
      namespace = "ingress-nginx"
      version   = var.nginx_ingress_version
      status    = try(helm_release.nginx_ingress[0].status, "unknown")
    } : null

    karpenter = var.enable_karpenter ? {
      name      = "karpenter"
      namespace = "karpenter"
      version   = var.karpenter_version
      status    = try(helm_release.karpenter[0].status, "unknown")
    } : null

    argocd = var.enable_argocd ? {
      name      = "argocd"
      namespace = "argocd"
      version   = var.argocd_version
      status    = try(helm_release.argocd[0].status, "unknown")
    } : null
  }
}