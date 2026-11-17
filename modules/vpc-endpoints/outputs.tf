# VPC Endpoints Module Outputs

# VPC Endpoints Information
output "vpc_endpoints" {
  description = "Information about all VPC endpoints"
  value = {
    for name, endpoint in aws_vpc_endpoint.endpoints : name => {
      id                = endpoint.id
      arn               = endpoint.arn
      dns_entry         = endpoint.dns_entry
      network_interface_ids = endpoint.network_interface_ids
      owner_id          = endpoint.owner_id
      policy            = endpoint.policy
      prefix_list_id    = endpoint.prefix_list_id
      requester_managed = endpoint.requester_managed
      route_table_ids   = endpoint.route_table_ids
      state            = endpoint.state
      vpc_endpoint_type = endpoint.vpc_endpoint_type
    }
  }
}

output "vpc_endpoint_ids" {
  description = "Map of VPC endpoint names to IDs"
  value = {
    for name, endpoint in aws_vpc_endpoint.endpoints : name => endpoint.id
  }
}

output "vpc_endpoint_dns_entries" {
  description = "DNS entries for all VPC endpoints"
  value = {
    for name, endpoint in aws_vpc_endpoint.endpoints : name => endpoint.dns_entry
  }
}

# Security Group Information
output "security_group_id" {
  description = "ID of the VPC endpoints security group"
  value       = aws_security_group.vpc_endpoints.id
}

output "security_group_arn" {
  description = "ARN of the VPC endpoints security group"
  value       = aws_security_group.vpc_endpoints.arn
}

# DNS Resolver Information
output "dns_resolver_endpoint" {
  description = "Route 53 resolver endpoint information"
  value = var.enable_dns_resolver ? {
    id             = aws_route53_resolver_endpoint.vpc_endpoints[0].id
    arn            = aws_route53_resolver_endpoint.vpc_endpoints[0].arn
    host_vpc_id    = aws_route53_resolver_endpoint.vpc_endpoints[0].host_vpc_id
    ip_addresses   = aws_route53_resolver_endpoint.vpc_endpoints[0].ip_address
  } : null
}

output "dns_resolver_rules" {
  description = "Route 53 resolver rules information"
  value = var.enable_dns_resolver ? {
    for name, rule in aws_route53_resolver_rule.vpc_endpoints : name => {
      id          = rule.id
      arn         = rule.arn
      domain_name = rule.domain_name
      rule_type   = rule.rule_type
    }
  } : {}
}

# Flow Logs Information
output "flow_logs" {
  description = "VPC flow logs information"
  value = var.enable_flow_logs ? {
    id             = aws_flow_log.vpc_endpoints[0].id
    arn            = aws_flow_log.vpc_endpoints[0].arn
    log_destination = aws_flow_log.vpc_endpoints[0].log_destination
    traffic_type   = aws_flow_log.vpc_endpoints[0].traffic_type
  } : null
}

output "flow_logs_log_group" {
  description = "CloudWatch log group for VPC endpoint flow logs"
  value = var.enable_flow_logs ? {
    name = aws_cloudwatch_log_group.vpc_endpoint_logs[0].name
    arn  = aws_cloudwatch_log_group.vpc_endpoint_logs[0].arn
  } : null
}

# Custom Endpoint Services
output "custom_endpoint_services" {
  description = "Custom VPC endpoint services information"
  value = {
    for name, service in aws_vpc_endpoint_service.custom_services : name => {
      id                    = service.id
      arn                   = service.arn
      service_name         = service.service_name
      service_type         = service.service_type
      acceptance_required  = service.acceptance_required
      manages_vpc_endpoints = service.manages_vpc_endpoints
    }
  }
}

# Endpoint Connection Notifications
output "endpoint_notifications" {
  description = "VPC endpoint connection notification information"
  value = {
    for name, notification in aws_vpc_endpoint_connection_notification.notifications : name => {
      id                    = notification.id
      notification_type     = notification.notification_type
      connection_events     = notification.connection_events
    }
  }
}

# Network Interface Information for Interface Endpoints
output "interface_endpoint_network_interfaces" {
  description = "Network interface IDs for interface endpoints"
  value = {
    for name, endpoint in aws_vpc_endpoint.endpoints : name => endpoint.network_interface_ids
    if var.vpc_endpoints[name].endpoint_type == "Interface"
  }
}

# Route Table Information for Gateway Endpoints
output "gateway_endpoint_route_tables" {
  description = "Route table IDs for gateway endpoints"
  value = {
    for name, endpoint in aws_vpc_endpoint.endpoints : name => endpoint.route_table_ids
    if var.vpc_endpoints[name].endpoint_type == "Gateway"
  }
}

# Cost and Resource Summary
output "resource_summary" {
  description = "Summary of VPC endpoints resources and estimated costs"
  value = {
    total_endpoints = length(aws_vpc_endpoint.endpoints)
    interface_endpoints = length([
      for name, config in var.vpc_endpoints : name 
      if config.endpoint_type == "Interface"
    ])
    gateway_endpoints = length([
      for name, config in var.vpc_endpoints : name 
      if config.endpoint_type == "Gateway"
    ])
    dns_resolver_enabled = var.enable_dns_resolver
    flow_logs_enabled   = var.enable_flow_logs
    
    # Cost estimates (approximate)
    estimated_monthly_cost = {
      interface_endpoints = "$\${length([for name, config in var.vpc_endpoints : name if config.endpoint_type == \"Interface\"]) * 7.20}"
      gateway_endpoints  = "$0.00"  # No hourly charge for Gateway endpoints
      data_processing   = "Variable based on usage"
      dns_resolver      = var.enable_dns_resolver ? "$0.125 per query (first 1B queries per month)" : "$0.00"
      flow_logs        = var.enable_flow_logs ? "Variable based on log volume" : "$0.00"
    }
  }
}

# Connection Information
output "connection_info" {
  description = "Connection information for applications using VPC endpoints"
  value = {
    endpoints_available = [for name in keys(aws_vpc_endpoint.endpoints) : name]
    private_dns_names = [
      for name, endpoint in aws_vpc_endpoint.endpoints : {
        endpoint_name = name
        dns_names    = [for dns in endpoint.dns_entry : dns.dns_name]
      }
      if var.vpc_endpoints[name].endpoint_type == "Interface" && var.vpc_endpoints[name].private_dns_enabled
    ]
    
    # AWS CLI examples
    aws_cli_examples = {
      s3_via_endpoint    = "aws s3 ls --region ${data.aws_region.current.name}  # Uses S3 VPC endpoint automatically"
      ecr_login         = "aws ecr get-login-password --region ${data.aws_region.current.name}  # Uses ECR VPC endpoints"
      secrets_access    = "aws secretsmanager get-secret-value --secret-id <secret-name> --region ${data.aws_region.current.name}"
    }
  }
}

# Note: Data sources are already defined in main.tf