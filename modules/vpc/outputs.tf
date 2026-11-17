# VPC Module Outputs - For use by other modules

# VPC Information
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.main.arn
}

# Subnet Information
output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "List of CIDR blocks of private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "private_subnet_arns" {
  description = "List of ARNs of private subnets"
  value       = aws_subnet.private[*].arn
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = var.enable_public_subnets ? aws_subnet.public[*].id : []
}

output "public_subnet_cidrs" {
  description = "List of CIDR blocks of public subnets"
  value       = var.enable_public_subnets ? aws_subnet.public[*].cidr_block : []
}

output "public_subnet_arns" {
  description = "List of ARNs of public subnets"
  value       = var.enable_public_subnets ? aws_subnet.public[*].arn : []
}

output "database_subnet_ids" {
  description = "List of IDs of database subnets"
  value       = var.enable_database_subnets ? aws_subnet.database[*].id : []
}

output "database_subnet_cidrs" {
  description = "List of CIDR blocks of database subnets"
  value       = var.enable_database_subnets ? aws_subnet.database[*].cidr_block : []
}

output "database_subnet_group_name" {
  description = "Name of the database subnet group"
  value       = var.enable_database_subnets ? aws_db_subnet_group.main[0].name : null
}

# Gateway Information
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = var.enable_internet_gateway ? aws_internet_gateway.main[0].id : null
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[*].id : []
}

output "nat_public_ips" {
  description = "List of public Elastic IPs associated with NAT Gateways"
  value       = var.enable_nat_gateway ? aws_eip.nat[*].public_ip : []
}

# Route Table Information
output "private_route_table_ids" {
  description = "List of IDs of private route tables"
  value       = aws_route_table.private[*].id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = var.enable_public_subnets ? aws_route_table.public[0].id : null
}

output "database_route_table_id" {
  description = "ID of the database route table"
  value       = var.enable_database_subnets ? aws_route_table.database[0].id : null
}

# Availability Zones
output "availability_zones" {
  description = "List of availability zones used"
  value       = local.azs
}

# Security Information
output "vpc_flow_log_group_name" {
  description = "Name of the CloudWatch log group for VPC Flow Logs"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_log[0].name : null
}

output "vpc_flow_log_group_arn" {
  description = "ARN of the CloudWatch log group for VPC Flow Logs"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_log[0].arn : null
}

# Network ACL Information
output "private_network_acl_id" {
  description = "ID of the private network ACL"
  value       = var.enable_network_acls ? aws_network_acl.private[0].id : null
}

output "public_network_acl_id" {
  description = "ID of the public network ACL"
  value       = var.enable_network_acls && var.enable_public_subnets ? aws_network_acl.public[0].id : null
}

# For EKS Module Integration
output "eks_subnet_tags" {
  description = "Map of subnet IDs to their types for EKS integration"
  value = merge(
    {
      for subnet in aws_subnet.private : subnet.id => {
        type = "private"
        az   = subnet.availability_zone
        cidr = subnet.cidr_block
      }
    },
    var.enable_public_subnets ? {
      for subnet in aws_subnet.public : subnet.id => {
        type = "public"
        az   = subnet.availability_zone
        cidr = subnet.cidr_block
      }
    } : {}
  )
}

# Security Group Defaults (for other modules to reference)
output "vpc_default_security_group_id" {
  description = "ID of the default security group for the VPC"
  value       = aws_vpc.main.default_security_group_id
}

# CIDR Information for Security Group Rules
output "vpc_cidr_blocks" {
  description = "List of CIDR blocks for the VPC (for security group rules)"
  value       = [aws_vpc.main.cidr_block]
}

# DNS Information
output "vpc_enable_dns_hostnames" {
  description = "Whether DNS hostnames are enabled in the VPC"
  value       = aws_vpc.main.enable_dns_hostnames
}

output "vpc_enable_dns_support" {
  description = "Whether DNS support is enabled in the VPC"
  value       = aws_vpc.main.enable_dns_support
}