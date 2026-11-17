# VPC Endpoints for AWS Services - Security Best Practice
# Enables private communication with AWS services without internet gateway

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoint" {
  count = var.enable_vpc_endpoints ? 1 : 0

  name_prefix = "${var.environment}-vpc-endpoint-"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment}-vpc-endpoint-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# S3 Gateway Endpoint (no cost)
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_vpc_endpoints && contains(var.vpc_endpoints, "s3") ? 1 : 0

  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  
  route_table_ids = concat(
    aws_route_table.private[*].id,
    var.enable_public_subnets ? [aws_route_table.public[0].id] : [],
    var.enable_database_subnets ? [aws_route_table.database[0].id] : []
  )

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.environment}-s3-endpoint"
  })
}

# Interface Endpoints (cost-optimized selection)
locals {
  interface_endpoints = {
    ec2 = {
      service_name = "com.amazonaws.${data.aws_region.current.name}.ec2"
      policy       = null
    }
    "ecr.api" = {
      service_name = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
      policy       = null
    }
    "ecr.dkr" = {
      service_name = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
      policy       = null
    }
    logs = {
      service_name = "com.amazonaws.${data.aws_region.current.name}.logs"
      policy       = null
    }
    sts = {
      service_name = "com.amazonaws.${data.aws_region.current.name}.sts"
      policy       = null
    }
    elasticloadbalancing = {
      service_name = "com.amazonaws.${data.aws_region.current.name}.elasticloadbalancing"
      policy       = null
    }
    autoscaling = {
      service_name = "com.amazonaws.${data.aws_region.current.name}.autoscaling"
      policy       = null
    }
    ssm = {
      service_name = "com.amazonaws.${data.aws_region.current.name}.ssm"
      policy       = null
    }
    ssmmessages = {
      service_name = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
      policy       = null
    }
    ec2messages = {
      service_name = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
      policy       = null
    }
    kms = {
      service_name = "com.amazonaws.${data.aws_region.current.name}.kms"
      policy       = null
    }
    secretsmanager = {
      service_name = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
      policy       = null
    }
  }

  # Filter endpoints based on configuration
  enabled_endpoints = {
    for k, v in local.interface_endpoints : k => v
    if var.enable_vpc_endpoints && contains(var.vpc_endpoints, k)
  }
}

# Create Interface Endpoints
resource "aws_vpc_endpoint" "interface" {
  for_each = local.enabled_endpoints

  vpc_id              = aws_vpc.main.id
  service_name        = each.value.service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint[0].id]
  
  # Enable private DNS names
  private_dns_enabled = true
  
  # Apply policy if specified
  policy = each.value.policy

  tags = merge(local.common_tags, {
    Name = "${var.environment}-${each.key}-endpoint"
  })
}

# Output VPC Endpoint information
output "vpc_endpoints" {
  description = "Map of VPC endpoints created"
  value = var.enable_vpc_endpoints ? merge(
    # S3 Gateway endpoint
    contains(var.vpc_endpoints, "s3") ? {
      s3 = {
        id           = aws_vpc_endpoint.s3[0].id
        arn          = aws_vpc_endpoint.s3[0].arn
        service_name = aws_vpc_endpoint.s3[0].service_name
        type         = "Gateway"
      }
    } : {},
    # Interface endpoints
    {
      for k, endpoint in aws_vpc_endpoint.interface : k => {
        id           = endpoint.id
        arn          = endpoint.arn
        service_name = endpoint.service_name
        type         = "Interface"
        dns_entries  = endpoint.dns_entry
      }
    }
  ) : {}
}

output "vpc_endpoint_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = var.enable_vpc_endpoints ? aws_security_group.vpc_endpoint[0].id : null
}