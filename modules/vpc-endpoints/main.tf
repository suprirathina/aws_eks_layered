#####################################
# VPC ENDPOINTS MODULE - Private AWS Service Access
#####################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.project_name}-${var.environment}-vpc-endpoints-"
  vpc_id      = var.vpc_id
  description = "Security group for VPC endpoints - private AWS service access"

  # HTTPS access from allowed CIDR blocks
  dynamic "ingress" {
    for_each = var.allowed_cidr_blocks
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "HTTPS access from ${ingress.value}"
    }
  }

  # HTTP access for specific services (if needed)
  dynamic "ingress" {
    for_each = var.allow_http_access ? var.allowed_cidr_blocks : []
    content {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "HTTP access from ${ingress.value}"
    }
  }

  # Custom port access
  dynamic "ingress" {
    for_each = var.custom_ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
    Module = "vpc-endpoints"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Dynamic VPC Endpoints (Interface and Gateway types)
resource "aws_vpc_endpoint" "endpoints" {
  for_each = var.vpc_endpoints

  vpc_id              = var.vpc_id
  service_name        = each.value.service_name
  vpc_endpoint_type   = each.value.endpoint_type
  
  # Interface endpoint configuration
  subnet_ids          = each.value.endpoint_type == "Interface" ? var.private_subnet_ids : null
  security_group_ids  = each.value.endpoint_type == "Interface" ? [aws_security_group.vpc_endpoints.id] : null
  private_dns_enabled = each.value.endpoint_type == "Interface" ? each.value.private_dns_enabled : null
  
  # Gateway endpoint configuration
  route_table_ids = each.value.endpoint_type == "Gateway" ? var.route_table_ids : null

  # Endpoint policy (Interface and Gateway): limits which actions/resources can be used through the endpoint
  # null = no policy sent, AWS default applies (full access)
  policy = each.value.policy != null ? jsonencode(each.value.policy) : null

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-${each.key}-endpoint"
    Module  = "vpc-endpoints"
    Service = each.key
  })
}

# CloudWatch Log Group for VPC Endpoint Access Logs
resource "aws_cloudwatch_log_group" "vpc_endpoint_logs" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/endpoints/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_id

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-vpc-endpoint-logs"
    Module      = "vpc-endpoints"
    Application = "networking"
  })
}

# VPC Flow Logs for VPC Endpoints (optional)
resource "aws_flow_log" "vpc_endpoints" {
  count           = var.enable_flow_logs ? 1 : 0
  iam_role_arn    = var.flow_logs_iam_role_arn
  log_destination = aws_cloudwatch_log_group.vpc_endpoint_logs[0].arn
  traffic_type    = var.flow_logs_traffic_type
  vpc_id          = var.vpc_id

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-vpc-endpoint-flow-logs"
    Module = "vpc-endpoints"
  })
}

# Creates a Route 53 Resolver endpoint: network interfaces that let DNS cross 
# between this VPC and onprem (INBOUND or OUTBOUND, set by dns_resolver_direction). 
#The VPC resolver itself already exists
resource "aws_route53_resolver_endpoint" "vpc_endpoints" {
  count     = var.enable_dns_resolver ? 1 : 0
  name      = "${var.project_name}-${var.environment}-vpc-endpoints-resolver-endpoint"
  direction = var.dns_resolver_direction

  security_group_ids = [aws_security_group.vpc_endpoints.id]

  dynamic "ip_address" {
    for_each = var.dns_resolver_subnets
    content {
      subnet_id = ip_address.value
      ip        = var.dns_resolver_ips != null ? var.dns_resolver_ips[ip_address.key] : null
    }
  }

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-vpc-endpoints-resolver-endpoint"
    Module = "vpc-endpoints"
  })
}

# Creates forwarding rules: send queries for chosen domains (e.g. corp.example.com) to onprem DNS servers
resource "aws_route53_resolver_rule" "vpc_endpoints" {
  for_each = var.enable_dns_resolver ? var.dns_resolver_rules : {}

 #domain name this rule applied to
  domain_name          = each.value.domain_name
  name                 = "${var.project_name}-${var.environment}-${each.key}-resolver-rule"
  rule_type            = each.value.rule_type
  resolver_endpoint_id = each.value.rule_type == "FORWARD" ? aws_route53_resolver_endpoint.vpc_endpoints[0].id : null

  dynamic "target_ip" {
    for_each = each.value.target_ips
    content {
      ip   = target_ip.value.ip
      port = target_ip.value.port
    }
  }

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-${each.key}-resolver-rule"
    Module = "vpc-endpoints"
  })
}

# Associate resolver rules with VPC
resource "aws_route53_resolver_rule_association" "vpc_endpoints" {
  for_each = var.enable_dns_resolver ? var.dns_resolver_rules : {}

  resolver_rule_id = aws_route53_resolver_rule.vpc_endpoints[each.key].id
  vpc_id          = var.vpc_id
}

# VPC Endpoint Service (for creating custom endpoints)
resource "aws_vpc_endpoint_service" "custom_services" {
  for_each = var.custom_endpoint_services

  acceptance_required        = each.value.acceptance_required
  network_load_balancer_arns = each.value.network_load_balancer_arns
  gateway_load_balancer_arns = each.value.gateway_load_balancer_arns
  
  allowed_principals         = each.value.allowed_principals
  private_dns_name          = each.value.private_dns_name

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-${each.key}-endpoint-service"
    Module = "vpc-endpoints"
  })
}

# VPC Endpoint Connection Notification
resource "aws_vpc_endpoint_connection_notification" "notifications" {
  for_each = var.endpoint_notifications

  vpc_endpoint_service_id     = each.value.vpc_endpoint_service_id
  connection_notification_arn = each.value.notification_arn
  connection_events          = each.value.connection_events
}

# Security Group Rules for specific endpoint requirements
resource "aws_security_group_rule" "additional_endpoint_rules" {
  for_each = var.additional_security_group_rules

  type              = each.value.type
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
  source_security_group_id = each.value.source_security_group_id
  security_group_id = aws_security_group.vpc_endpoints.id
  description       = each.value.description
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}