# Enterprise Observability Module

## Overview
This module provides **comprehensive enterprise observability** with AWS native monitoring services, including CloudWatch Container Insights, Amazon Managed Prometheus, Amazon Managed Grafana, centralized logging, and intelligent alerting for EKS environments.

## Observability Features

### 📊 **Monitoring & Metrics**
- **CloudWatch Container Insights**: Deep EKS cluster and workload monitoring
- **Amazon Managed Prometheus**: High-cardinality metrics with long-term storage
- **Amazon Managed Grafana**: Rich visualization dashboards and alerting
- **Custom Dashboards**: Pre-built dashboards for EKS and application metrics

### 📋 **Logging & Analysis**
- **Centralized Logging**: Structured log aggregation across all services
- **Log Insights**: Advanced query capabilities with saved queries
- **FluentBit Integration**: Efficient log shipping and processing
- **Log Retention**: Configurable retention policies for compliance

### 🔔 **Alerting & Notifications**
- **CloudWatch Alarms**: Resource and application-based alerting
- **SNS Integration**: Multi-channel notification delivery
- **EventBridge Rules**: Event-driven observability automation
- **Intelligent Routing**: Context-aware alert distribution

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                 Enterprise Observability Platform           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ CloudWatch  │  │  Managed    │  │  Managed    │        │
│  │ Container   │  │ Prometheus  │  │  Grafana    │        │
│  │ Insights    │  │   (AMP)     │  │   (AMG)     │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                 Data Collection Layer                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ CloudWatch  │  │ FluentBit   │  │    ADOT     │        │
│  │   Agent     │  │ Log Shipper │  │ Collector   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                 Processing & Storage                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Kinesis     │  │     S3      │  │   Lambda    │        │
│  │ Firehose    │  │Log Storage  │  │Log Processor│        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                 Alerting & Response                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ CloudWatch  │  │ EventBridge │  │     SNS     │        │
│  │   Alarms    │  │    Rules    │  │ Notifications│        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Usage
```hcl
module "observability" {
  source = "../modules/observability"
  
  environment  = "prod"
  cluster_name = "production-eks"
  
  # EKS integration
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.irsa_oidc_provider_url
  
  # Enable core observability services
  enable_container_insights    = true
  enable_prometheus           = true
  enable_grafana              = true
  enable_cloudwatch_dashboards = true
  enable_cloudwatch_alarms    = true
  
  tags = {
    Project = "enterprise-platform"
    Owner   = "platform-team"
  }
}
```

### Production Configuration with Advanced Features
```hcl
module "observability" {
  source = "../modules/observability"
  
  environment  = "prod"
  cluster_name = "production-eks"
  
  # EKS integration
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.irsa_oidc_provider_url
  logs_kms_key_id   = module.security.kms_key_arns["security-logs"]
  
  # CloudWatch configuration
  enable_container_insights         = true
  container_insights_log_retention = 90
  
  cloudwatch_log_groups = {
    "application" = {
      retention_days = 90
      application   = "microservices"
    }
    "dataplane" = {
      retention_days = 30
      application   = "kubernetes-system"
    }
    "host" = {
      retention_days = 30
      application   = "node-system"
    }
    "performance" = {
      retention_days = 14
      application   = "performance-monitoring"
    }
  }
  
  # Prometheus and Grafana
  enable_prometheus = true
  enable_grafana   = true
  
  grafana_authentication_providers = ["AWS_SSO"]
  grafana_data_sources = ["CLOUDWATCH", "PROMETHEUS", "XRAY"]
  grafana_notification_destinations = ["SNS"]
  
  # Enhanced CloudWatch alarms
  enable_cloudwatch_alarms = true
  cloudwatch_alarms = {
    "critical-cpu-utilization" = {
      alarm_description   = "Critical CPU utilization on EKS nodes"
      alarm_type         = "resource"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name        = "node_cpu_utilization"
      namespace          = "ContainerInsights"
      period             = 300
      statistic          = "Average"
      threshold          = 90
      alarm_actions      = ["arn:aws:sns:us-east-1:123456789012:critical-alerts"]
    }
    
    "critical-memory-utilization" = {
      alarm_description   = "Critical memory utilization on EKS nodes"
      alarm_type         = "resource"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name        = "node_memory_utilization"
      namespace          = "ContainerInsights"
      period             = 300
      statistic          = "Average"
      threshold          = 95
      alarm_actions      = ["arn:aws:sns:us-east-1:123456789012:critical-alerts"]
    }
    
    "pod-crash-looping" = {
      alarm_description   = "Pods are crash looping"
      alarm_type         = "application"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 1
      metric_name        = "pod_number_of_container_restarts"
      namespace          = "ContainerInsights"
      period             = 300
      statistic          = "Sum"
      threshold          = 10
      alarm_actions      = ["arn:aws:sns:us-east-1:123456789012:critical-alerts"]
    }
    
    "api-server-latency" = {
      alarm_description   = "High API server latency"
      alarm_type         = "control-plane"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 3
      metric_name        = "cluster_failed_request_count"
      namespace          = "AWS/EKS"
      period             = 300
      statistic          = "Sum"
      threshold          = 5
      alarm_actions      = ["arn:aws:sns:us-east-1:123456789012:warning-alerts"]
    }
  }
  
  # SNS alerting with multi-channel notifications
  sns_alert_topics = {
    "critical-alerts" = {
      display_name = "Critical Production Alerts"
      purpose      = "critical-monitoring"
      subscriptions = [
        {
          protocol = "email"
          endpoint = "oncall-team@company.com"
        },
        {
          protocol = "sms"
          endpoint = "+1234567890"
        },
        {
          protocol = "https"
          endpoint = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
        }
      ]
    }
    
    "warning-alerts" = {
      display_name = "Warning Production Alerts"
      purpose      = "warning-monitoring"
      subscriptions = [
        {
          protocol = "email"
          endpoint = "platform-team@company.com"
          filter_policy = {
            severity = ["warning"]
          }
        }
      ]
    }
    
    "info-alerts" = {
      display_name = "Informational Alerts"
      purpose      = "info-monitoring"
      subscriptions = [
        {
          protocol = "https"
          endpoint = "https://hooks.slack.com/services/YOUR/TEAM/WEBHOOK"
        }
      ]
    }
  }
  
  # Advanced logging with FluentBit
  enable_fluentbit = true
  firehose_buffer_size = 10
  firehose_buffer_interval = 60
  observability_logs_retention_days = 2555  # 7 years for compliance
  
  # Log Insights queries for troubleshooting
  enable_log_insights = true
  log_insights_queries = {
    "error-analysis" = {
      log_group_names = [
        "/aws/containerinsights/${var.cluster_name}/application"
      ]
      query_string = "fields @timestamp, @message, kubernetes.namespace_name, kubernetes.pod_name | filter @message like /ERROR/ or @message like /FATAL/ | sort @timestamp desc | limit 100"
    }
    
    "performance-analysis" = {
      log_group_names = [
        "/aws/containerinsights/${var.cluster_name}/performance"
      ]
      query_string = "fields @timestamp, @duration, kubernetes.namespace_name | filter @type = \"REPORT\" | stats avg(@duration), max(@duration), min(@duration) by bin(5m), kubernetes.namespace_name"
    }
    
    "security-events" = {
      log_group_names = [
        "/aws/containerinsights/${var.cluster_name}/application"
      ]
      query_string = "fields @timestamp, @message, kubernetes.namespace_name | filter @message like /SECURITY/ or @message like /UNAUTHORIZED/ | sort @timestamp desc | limit 50"
    }
    
    "network-analysis" = {
      log_group_names = [
        "/aws/containerinsights/${var.cluster_name}/dataplane"
      ]
      query_string = "fields @timestamp, @message | filter @message like /NetworkPolicy/ or @message like /DENY/ | sort @timestamp desc | limit 100"
    }
  }
  
  # X-Ray tracing for distributed applications
  enable_xray_tracing = true
  xray_sampling_priority = 9000
  xray_reservoir_size = 2
  xray_fixed_rate = 0.1
  
  # ADOT collector for OpenTelemetry
  enable_adot_collector = true
  
  # EventBridge for observability automation
  enable_observability_events = true
  observability_event_rules = {
    "high-error-rate" = {
      description = "High error rate detected in applications"
      event_pattern = {
        source = ["aws.logs"]
        "detail-type" = ["CloudWatch Logs Subscription Filter"]
        detail = {
          errorCount = {
            numeric = [">", 10]
          }
        }
      }
      target_arn = "arn:aws:sns:us-east-1:123456789012:critical-alerts"
      enabled = true
      
      input_transformer = {
        input_paths = {
          errorCount = "$.detail.errorCount"
          logGroup = "$.detail.logGroup"
        }
        input_template = jsonencode({
          alertType = "High Error Rate"
          cluster = var.cluster_name
          environment = var.environment
          errorCount = "<errorCount>"
          logGroup = "<logGroup>"
          message = "High error rate detected in <logGroup>. Error count: <errorCount>"
        })
      }
    }
  }
  
  # Cross-account monitoring setup
  enable_cross_account_monitoring = true
  monitoring_account_trusted_principals = [
    "arn:aws:iam::999999999999:role/CentralMonitoringRole"
  ]
  monitoring_external_id = "unique-monitoring-id-123"
  
  # Cost monitoring
  enable_cost_monitoring = true
  cost_monitoring_config = {
    daily_budget_limit = 200
    monthly_budget_limit = 5000
    cost_anomaly_detection = true
    unused_resource_alerts = true
  }
  
  # Compliance requirements
  compliance_requirements = {
    log_retention_years = 7
    audit_trail_required = true
    data_residency_region = "us-east-1"
    encryption_required = true
  }
  
  tags = {
    Environment = "production"
    Project     = "enterprise-platform"
    Owner       = "platform-team"
    CostCenter  = "engineering"
    Compliance  = "SOC2,HIPAA"
  }
}
```

### Development Environment Configuration
```hcl
module "observability" {
  source = "../modules/observability"
  
  environment  = "dev"
  cluster_name = "development-eks"
  
  # EKS integration
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.irsa_oidc_provider_url
  
  # Cost-optimized configuration for development
  enable_container_insights    = true
  enable_prometheus           = false  # Disabled for cost savings
  enable_grafana              = false  # Use CloudWatch dashboards only
  enable_cloudwatch_dashboards = true
  enable_cloudwatch_alarms    = false  # Disabled in dev
  
  # Reduced log retention
  container_insights_log_retention = 7
  cloudwatch_log_groups = {
    "application" = {
      retention_days = 7
    }
    "dataplane" = {
      retention_days = 3
    }
  }
  
  # Minimal alerting
  sns_alert_topics = {
    "dev-alerts" = {
      display_name = "Development Alerts"
      purpose      = "dev-monitoring"
      subscriptions = [
        {
          protocol = "email"
          endpoint = "dev-team@company.com"
        }
      ]
    }
  }
  
  # Basic observability features
  enable_log_insights = true
  enable_xray_tracing = false
  enable_fluentbit   = false
  enable_adot_collector = false
  
  tags = {
    Environment = "development"
    Project     = "enterprise-platform"
    Owner       = "dev-team"
  }
}
```

## Observability Best Practices

### 1. **Comprehensive Monitoring**
```hcl
# Enable all core monitoring services
enable_container_insights = true
enable_prometheus        = true
enable_grafana          = true
enable_cloudwatch_alarms = true
```

### 2. **Structured Logging**
```hcl
# Configure log groups by application tier
cloudwatch_log_groups = {
  "application"  = { retention_days = 90 }
  "system"      = { retention_days = 30 }
  "performance" = { retention_days = 14 }
  "debug"       = { retention_days = 7 }
}
```

### 3. **Intelligent Alerting**
```hcl
# Set up tiered alerting based on severity
sns_alert_topics = {
  "critical-alerts" = {  # Page on-call team
    subscriptions = [
      { protocol = "sms", endpoint = "+1234567890" },
      { protocol = "email", endpoint = "oncall@company.com" }
    ]
  }
  "warning-alerts" = {   # Notify during business hours
    subscriptions = [
      { protocol = "email", endpoint = "platform-team@company.com" }
    ]
  }
}
```

### 4. **Cost Optimization**
```hcl
# Environment-specific configurations
variable "observability_configs" {
  default = {
    prod = {
      prometheus_enabled = true
      log_retention = 90
      xray_sampling = 0.1
    }
    dev = {
      prometheus_enabled = false
      log_retention = 7
      xray_sampling = 0.01
    }
  }
}
```

## Kubernetes Integration

### Service Account Configurations
```yaml
# CloudWatch Agent
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloudwatch-agent
  namespace: amazon-cloudwatch
  annotations:
    eks.amazonaws.com/role-arn: ${module.observability.irsa_roles.cloudwatch_agent.arn}
```

### Prometheus Configuration
```yaml
# Prometheus Server
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus-server
  namespace: prometheus
  annotations:
    eks.amazonaws.com/role-arn: ${module.observability.irsa_roles.prometheus_remote_write.arn}
```

### FluentBit Configuration
```yaml
# FluentBit DaemonSet
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluent-bit
  namespace: amazon-cloudwatch
  annotations:
    eks.amazonaws.com/role-arn: ${module.observability.irsa_roles.fluentbit.arn}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name | `string` | n/a | yes |
| cluster_name | EKS cluster name | `string` | n/a | yes |
| oidc_provider_arn | EKS OIDC provider ARN | `string` | n/a | yes |
| oidc_issuer_url | EKS OIDC issuer URL | `string` | n/a | yes |
| enable_container_insights | Enable Container Insights | `bool` | `true` | no |
| enable_prometheus | Enable Managed Prometheus | `bool` | `true` | no |
| enable_grafana | Enable Managed Grafana | `bool` | `true` | no |
| logs_kms_key_id | KMS key for log encryption | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| prometheus_workspace | Prometheus workspace information |
| grafana_workspace | Grafana workspace information |
| cloudwatch_dashboards | CloudWatch dashboards created |
| irsa_roles | IAM roles for Kubernetes service accounts |
| monitoring_endpoints | Service endpoints for integration |

## Cost Optimization

### 1. **Environment-Based Scaling**
```hcl
# Production: Full observability
enable_prometheus = true
enable_grafana   = true
log_retention   = 90

# Development: Essential monitoring only
enable_prometheus = false
enable_grafana   = false  
log_retention   = 7
```

### 2. **Log Retention Management**
```hcl
# Tiered retention based on log importance
cloudwatch_log_groups = {
  "critical-logs"  = { retention_days = 365 }
  "business-logs"  = { retention_days = 90 }
  "system-logs"    = { retention_days = 30 }
  "debug-logs"     = { retention_days = 7 }
}
```

### 3. **Sampling Rate Optimization**
```hcl
# Adjust X-Ray sampling based on environment
xray_fixed_rate = var.environment == "prod" ? 0.1 : 0.01
```

## Troubleshooting

### Issue: High CloudWatch costs
**Solution**: Optimize log retention and disable unnecessary services in non-production
```bash
# Review log group usage
aws logs describe-log-groups --query 'logGroups[*].[logGroupName,storedBytes]' --output table

# Check metric usage
aws cloudwatch list-metrics --namespace AWS/EKS
```

### Issue: Prometheus metrics not appearing
**Solution**: Verify IRSA role and remote write configuration
```bash
# Check service account annotations
kubectl describe serviceaccount prometheus-server -n prometheus

# Verify remote write endpoint
kubectl logs deployment/prometheus-server -n prometheus
```

### Issue: Grafana dashboard empty
**Solution**: Verify data source configuration and IAM permissions
```bash
# Check Grafana service role
aws iam list-attached-role-policies --role-name grafana-service-role

# Test CloudWatch API access
aws cloudwatch list-metrics --namespace ContainerInsights
```

## References
- [CloudWatch Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html)
- [Amazon Managed Service for Prometheus](https://docs.aws.amazon.com/prometheus/latest/userguide/what-is-Amazon-Managed-Service-Prometheus.html)
- [Amazon Managed Grafana](https://docs.aws.amazon.com/grafana/latest/userguide/what-is-Amazon-Managed-Service-Grafana.html)