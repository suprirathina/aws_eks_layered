# Example Outputs

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.alb.load_balancer_dns_name
}

output "alb_url" {
  description = "URL to access the load balancer"
  value       = module.alb.load_balancer_url
}

output "cloudwatch_integration" {
  description = "CloudWatch integration details"
  value       = module.alb.cloudwatch_integration
}

output "monitoring_urls" {
  description = "URLs for monitoring and observability"
  value       = module.alb.monitoring_urls
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${var.project_name}-${var.environment}-alb"
}