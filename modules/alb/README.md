# ALB Module - Enterprise Load Balancer with CloudWatch Integration

## Overview

This module creates an Application Load Balancer (ALB) with optional access logging and CloudWatch integration for comprehensive monitoring and observability.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Internet/VPC  │───▶│  Application LB  │───▶│  Target Groups  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │   Access Logs    │
                       │    (S3 Bucket)   │
                       └──────────────────┘
                                │
                                ▼ (Optional)
                       ┌──────────────────┐    ┌─────────────────┐
                       │ Lambda Processor │───▶│   CloudWatch    │
                       │  (Log Analysis)  │    │   Metrics       │
                       └──────────────────┘    └─────────────────┘
```

## Features

### Core ALB Features
- ✅ Application Load Balancer with security groups
- ✅ HTTP/HTTPS listeners with SSL termination
- ✅ Multiple target groups with health checks
- ✅ Advanced routing rules and conditions
- ✅ Internal or internet-facing configuration

### Access Logging
- ✅ S3-based access log storage
- ✅ Configurable retention policies
- ✅ Cost-optimized lifecycle management
- ✅ Disabled by default for cost control

### CloudWatch Integration
- ✅ Lambda-based log processing
- ✅ Real-time metric extraction
- ✅ Custom CloudWatch metrics
- ✅ Performance and error analytics
- ✅ Disabled by default for cost control

## Usage

### Basic ALB (No Logging)
```hcl
module "alb" {
  source = "../../modules/alb"

  project_name = "myapp"
  environment  = "dev"
  
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  
  # Basic configuration
  internal     = false
  enable_http  = true
  enable_https = false
  
  # Target groups
  target_groups = {
    web = {
      port                 = 80
      protocol            = "HTTP"
      target_type         = "instance"
      health_check_path   = "/"
      health_check_matcher = "200"
    }
  }
  
  # Routing rules
  listener_rules = {
    web = {
      priority = 100
      action = {
        type             = "forward"
        target_group_key = "web"
      }
      conditions = [{
        type   = "path-pattern"
        values = ["/*"]
      }]
    }
  }
}
```

### ALB with Access Logs
```hcl
module "alb" {
  source = "../../modules/alb"
  
  # ... basic configuration ...
  
  # Enable S3 access logging
  enable_access_logs         = true
  access_logs_retention_days = 30
}
```

### ALB with Full CloudWatch Integration
```hcl
module "alb" {
  source = "../../modules/alb"
  
  # ... basic configuration ...
  
  # Enable full monitoring
  enable_access_logs           = true
  enable_cloudwatch_integration = true
  cloudwatch_log_group_name    = "/aws/alb/myapp/dev"
  access_logs_retention_days   = 7  # Short retention for cost
}
```

## CloudWatch Metrics

When CloudWatch integration is enabled, the following custom metrics are available:

| Metric Name | Description | Unit |
|-------------|-------------|------|
| `TotalRequests` | Total number of requests processed | Count |
| `Status2xxPercent` | Percentage of successful responses | Percent |
| `Status4xxPercent` | Percentage of client errors | Percent |
| `Status5xxPercent` | Percentage of server errors | Percent |
| `AverageResponseTime` | Average response time | Seconds |
| `MaxResponseTime` | Maximum response time | Seconds |
| `P95ResponseTime` | 95th percentile response time | Seconds |
| `Throughput` | Requests per minute | Count/Min |
| `ErrorRate` | Combined 4xx + 5xx error rate | Percent |

### Viewing Metrics
```bash
# CloudWatch Console
https://console.aws.amazon.com/cloudwatch/home#metricsV2:graph=~();namespace=ALB/ProcessedMetrics

# CLI Query
aws cloudwatch get-metric-statistics \
  --namespace ALB/ProcessedMetrics \
  --metric-name ErrorRate \
  --dimensions Name=Project,Value=myapp Name=Environment,Value=dev \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T01:00:00Z \
  --period 300 \
  --statistics Average
```

## Cost Considerations

### Default Configuration (Cost-Optimized)
- ✅ Access logs: **Disabled**
- ✅ CloudWatch integration: **Disabled**
- ✅ Monthly cost: **~$16.20** (ALB + basic metrics only)

### With Access Logs Enabled
- 📊 S3 storage: **~$0.023/GB/month**
- 📊 Lambda processing: **~$0.20/month** (with integration)
- 📊 CloudWatch custom metrics: **~$0.30/metric/month**
- ⚠️ Monthly cost increase: **~$3-8** depending on traffic

### Cost Optimization Features
- Automatic S3 lifecycle policies
- Configurable log retention
- Lambda cold-start optimization
- Batched metric publishing

## Security Features

### Network Security
- VPC-based security groups
- Configurable ingress rules
- Support for internal/external access
- SSL/TLS termination

### Access Control
- IAM roles for Lambda processing
- Least-privilege permissions
- S3 bucket policies
- CloudWatch access controls

### Compliance
- Access log encryption in transit
- S3 bucket encryption at rest
- CloudWatch log encryption
- Audit trail via CloudTrail

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project_name` | Project name for resource naming | `string` | | yes |
| `environment` | Environment name (dev/staging/prod) | `string` | | yes |
| `vpc_id` | VPC ID where ALB will be created | `string` | | yes |
| `public_subnet_ids` | List of public subnet IDs | `list(string)` | | yes |
| `private_subnet_ids` | List of private subnet IDs | `list(string)` | | yes |
| `internal` | Whether ALB is internal or internet-facing | `bool` | `false` | no |
| `enable_access_logs` | Enable ALB access logs to S3 | `bool` | `false` | no |
| `enable_cloudwatch_integration` | Enable CloudWatch integration | `bool` | `false` | no |
| `cloudwatch_log_group_name` | Custom CloudWatch log group name | `string` | `null` | no |
| `access_logs_retention_days` | Days to retain access logs | `number` | `30` | no |

## Outputs

| Name | Description |
|------|-------------|
| `load_balancer_arn` | ARN of the load balancer |
| `load_balancer_dns_name` | DNS name of the load balancer |
| `target_group_arns` | Map of target group ARNs |
| `security_group_id` | ID of the ALB security group |
| `access_logs_bucket` | S3 bucket for access logs (if enabled) |
| `cloudwatch_integration` | CloudWatch integration details |
| `monitoring_urls` | Console URLs for monitoring |

## Examples

See the [environments/micro](../../environments/micro/) directory for a complete implementation example.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.0 |

## Lambda Integration

The CloudWatch integration uses a Python Lambda function that:

1. **Processes ALB logs** from S3 in near real-time
2. **Extracts key metrics** (response times, error rates, throughput)
3. **Publishes to CloudWatch** with proper dimensions
4. **Handles gzipped logs** automatically
5. **Batches metric calls** for efficiency

### Lambda Function Details
- **Runtime**: Python 3.9
- **Timeout**: 5 minutes
- **Memory**: 128 MB (sufficient for log processing)
- **Triggers**: S3 object creation events
- **Permissions**: Read S3, write CloudWatch metrics

## Troubleshooting

### Common Issues

1. **Lambda not triggered**
   - Check S3 bucket notification configuration
   - Verify Lambda permissions
   - Check CloudWatch logs for errors

2. **No metrics in CloudWatch**
   - Verify Lambda execution logs
   - Check IAM permissions for CloudWatch
   - Ensure log files contain valid ALB log format

3. **High costs**
   - Reduce log retention days
   - Consider disabling integration in dev environments
   - Monitor S3 storage usage

### Debug Commands
```bash
# Check Lambda logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/myapp-dev-alb-log-processor"

# Test Lambda function
aws lambda invoke --function-name myapp-dev-alb-log-processor --payload '{}' response.json

# Check CloudWatch metrics
aws cloudwatch list-metrics --namespace ALB/ProcessedMetrics
```

## Enterprise Standards

This module follows enterprise standards for:
- ✅ **Naming conventions**: Consistent resource naming
- ✅ **Tagging strategy**: Comprehensive resource tagging  
- ✅ **Security practices**: Least privilege access
- ✅ **Cost optimization**: Default disabled expensive features
- ✅ **Monitoring**: Comprehensive observability
- ✅ **Documentation**: Complete usage examples
- ✅ **Compliance**: Security and audit requirements