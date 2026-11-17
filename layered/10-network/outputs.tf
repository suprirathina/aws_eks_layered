# VPC-Only Outputs - Other modules are commented out in main.tf

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "database_subnet_ids" {
  description = "IDs of the database subnets"
  value       = module.vpc.database_subnet_ids
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "region" {
  description = "AWS region"
  value       = var.region
}

# Basic Network Architecture Summary (VPC only)
output "network_architecture" {
  description = "VPC network architecture summary"
  value = {
    vpc_id                = module.vpc.vpc_id
    vpc_cidr              = module.vpc.vpc_cidr_block
    private_subnets       = module.vpc.private_subnet_ids
    public_subnets        = module.vpc.public_subnet_ids
    database_subnets      = module.vpc.database_subnet_ids
    internet_gateway      = "Enabled for public subnet access"
    nat_gateway          = "Disabled for cost optimization"
    vpc_endpoints        = "Disabled for cost optimization"
    availability_zones    = length(module.vpc.private_subnet_ids)
  }
}

# Cost Information for VPC Only
output "estimated_daily_cost" {
  description = "Estimated daily cost for VPC infrastructure"
  value = {
    vpc_resources         = "$0/day (VPC, subnets, route tables, IGW are free)"
    nat_gateway          = "$0/day (disabled - would be ~$90/month for 2 AZs)"
    vpc_endpoints        = "$0/day (disabled - would be ~$79/month for 11 endpoints)"  
    flow_logs            = "$0/day (disabled - would be $75-750/month)"
    
    total_daily_cost     = "~$0-2/day"
    total_monthly_cost   = "~$0-60/month"
    
    cost_savings = {
      vs_full_vpc = "~$244+/month saved by disabling expensive features"
      note = "Only minimal data transfer charges may apply"
    }
  }
}

# Added for the layered layout: read by layer 15-vpc-endpoints through remote state
output "private_route_table_ids" {
  description = "IDs of the private route tables"
  value       = module.vpc.private_route_table_ids
}
