# ALB Module Outputs

# Load Balancer Information
output "load_balancer_id" {
  description = "ID of the load balancer"
  value       = aws_lb.main.id
}

output "load_balancer_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

# Security Group Information
output "security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

# Listener Information
output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = var.enable_http ? aws_lb_listener.http[0].arn : null
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = var.enable_https ? aws_lb_listener.https[0].arn : null
}

# Target Group Information
output "target_group_arns" {
  description = "ARNs of all target groups"
  value = {
    for name, tg in aws_lb_target_group.target_groups : name => tg.arn
  }
}

output "target_group_names" {
  description = "Names of all target groups"
  value = {
    for name, tg in aws_lb_target_group.target_groups : name => tg.name
  }
}

# Access Logs Information
output "access_logs_bucket" {
  description = "S3 bucket for access logs (if enabled)"
  value       = var.enable_access_logs ? aws_s3_bucket.alb_logs[0].id : null
}

# Connection Information
output "load_balancer_url" {
  description = "URL to access the load balancer"
  value       = var.enable_https ? "https://${aws_lb.main.dns_name}" : "http://${aws_lb.main.dns_name}"
}

output "load_balancer_endpoints" {
  description = "Available endpoints on the load balancer"
  value = {
    http  = var.enable_http ? "http://${aws_lb.main.dns_name}" : "Not enabled"
    https = var.enable_https ? "https://${aws_lb.main.dns_name}" : "Not enabled"
  }
}

# Configuration Summary
output "configuration_summary" {
  description = "Summary of ALB configuration"
  value = {
    name                    = aws_lb.main.name
    type                   = aws_lb.main.load_balancer_type
    scheme                 = aws_lb.main.internal ? "internal" : "internet-facing"
    vpc_id                 = var.vpc_id
    subnets                = aws_lb.main.subnets
    security_groups        = aws_lb.main.security_groups
    deletion_protection    = aws_lb.main.enable_deletion_protection
    access_logs_enabled    = var.enable_access_logs
    http_enabled          = var.enable_http
    https_enabled         = var.enable_https
    target_group_count    = length(aws_lb_target_group.target_groups)
    listener_rule_count   = length(var.listener_rules)
  }
}

# CloudWatch Integration Information
output "cloudwatch_integration" {
  description = "CloudWatch integration configuration and resources"
  value = var.enable_access_logs && var.enable_cloudwatch_integration ? {
    enabled             = true
    log_group_name      = aws_cloudwatch_log_group.alb_metrics[0].name
    log_group_arn       = aws_cloudwatch_log_group.alb_metrics[0].arn
    lambda_function_arn = aws_lambda_function.alb_log_processor[0].arn
    lambda_function_name = aws_lambda_function.alb_log_processor[0].function_name
    metrics_namespace   = "ALB/ProcessedMetrics"
    dashboard_url       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#metricsV2:graph=~();namespace=ALB/ProcessedMetrics"
  } : {
    enabled = false
    message = "CloudWatch integration is disabled. Enable by setting enable_access_logs=true and enable_cloudwatch_integration=true"
  }
}

output "monitoring_urls" {
  description = "URLs for monitoring and observability"
  value = {
    alb_console = "https://${data.aws_region.current.name}.console.aws.amazon.com/ec2/v2/home?region=${data.aws_region.current.name}#LoadBalancers:search=${aws_lb.main.name}"
    s3_logs     = var.enable_access_logs ? "https://s3.console.aws.amazon.com/s3/buckets/${aws_s3_bucket.alb_logs[0].id}" : "Access logs not enabled"
    cloudwatch_metrics = var.enable_access_logs && var.enable_cloudwatch_integration ? 
      "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#metricsV2:graph=~();namespace=ALB/ProcessedMetrics" : 
      "CloudWatch integration not enabled"
  }
}