# Enterprise VPC Module with Security Best Practices
# This module creates a secure, multi-AZ VPC suitable for EKS workloads

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources for availability zones and region
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

locals {
  # Use first 2 AZs for high availability
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  
  # Calculate CIDR blocks for subnets
  private_subnets = [
    for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 1)
  ]
  
  public_subnets = [
    for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 101)
  ]
  
  database_subnets = [
    for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 201)
  ]
  
  # Common tags for all resources
  common_tags = merge(
    var.tags,
    {
      Module      = "vpc"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# Main VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  //enables DNS names for EC2. EKS worker nodes and pods needs DNS to communicate properly
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.environment}-vpc"
  })
}

# Internet Gateway (for Load Balancers only)
resource "aws_internet_gateway" "main" {
  count  = var.enable_internet_gateway ? 1 : 0

  # id is automatically assigned by AWS after VPC is created.
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.environment}-igw"
  })
}

# Private Subnets (for EKS nodes and workloads)
resource "aws_subnet" "private" {
  count = length(local.private_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]

  # Security: No public IP assignment
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.environment}-private-${local.azs[count.index]}"
    Type = "private"
    # EKS subnet tags for auto-discovery
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/internal-elb"           = "1"
  })
}

# Public Subnets (minimal, for load balancers only)
resource "aws_subnet" "public" {
  count = var.enable_public_subnets ? length(local.public_subnets) : 0

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_subnets[count.index]
  availability_zone = local.azs[count.index]

  # load balancers will get public IP assigned by AWS. 
  # Security: No public IP assignment
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.environment}-public-${local.azs[count.index]}"
    Type = "public"
    # EKS subnet tags for load balancers
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/elb"                    = "1"
  })
}

# Database Subnets (isolated)
resource "aws_subnet" "database" {
  count = var.enable_database_subnets ? length(local.database_subnets) : 0

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.database_subnets[count.index]
  availability_zone = local.azs[count.index]

  # Security: No public IP assignment
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.environment}-database-${local.azs[count.index]}"
    Type = "database"
  })
}

# Database Subnet Group that tells RDS where it's allowed to place database instance
resource "aws_db_subnet_group" "main" {
  count = var.enable_database_subnets ? 1 : 0

  name       = "${var.environment}-db-subnet-group"
  
  #TF Splat operator gets all subnet ids in one shot.
  subnet_ids = aws_subnet.database[*].id

  tags = merge(local.common_tags, {
    Name = "${var.environment}-db-subnet-group"
  })
}

# Elastic IP for NAT Gateway  which is optional, disabled by default for security/cost
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? length(aws_subnet.public) : 0

  domain = "vpc"
  
  depends_on = [aws_internet_gateway.main]

  tags = merge(local.common_tags, {
    Name = "${var.environment}-nat-eip-${count.index + 1}"
  })
}

# NAT Gateway (optional, disabled by default for security/cost)
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? length(aws_subnet.public) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.main]

  tags = merge(local.common_tags, {
    Name = "${var.environment}-nat-${local.azs[count.index]}"
  })
}

# seperate Route Tables for each of the private subnet
resource "aws_route_table" "private" {
  count = length(aws_subnet.private)

  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.environment}-private-rt-${local.azs[count.index]}"
    Type = "private"
  })
}

#shared Route table for public subnet
resource "aws_route_table" "public" {
  count = var.enable_public_subnets ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.environment}-public-rt"
    Type = "public"
  })
}


#shared Route table for database subnet
resource "aws_route_table" "database" {
  count = var.enable_database_subnets ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.environment}-database-rt"
    Type = "database"
  })
}

# Add route to internet to public route table
resource "aws_route" "public_internet" {
  count = var.enable_public_subnets && var.enable_internet_gateway ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  
  # Default route: Send all non-VPC traffic (0.0.0.0/0) to Internet Gateway
  # Note: VPC traffic (10.0.0.0/16) uses the local route instead (longest prefix match)
  destination_cidr_block = "0.0.0.0/0"
  
  # Directing this traffic to IGW
  gateway_id             = aws_internet_gateway.main[0].id
}

# Add route to private route table
resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? length(aws_route_table.private) : 0

  route_table_id         = aws_route_table.private[count.index].id
  
  # Adding 0.0.0.0/0 represents traffic NOT for any VPC resource
  destination_cidr_block = "0.0.0.0/0"
  
  # Directing this traffic to NAT GW
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

# Associate each private subnet with its dedicated private route table 
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# associate public RT with public subnets 
resource "aws_route_table_association" "public" {
  count = var.enable_public_subnets ? length(aws_subnet.public) : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# associate dbatabase RT with database subnets 
resource "aws_route_table_association" "database" {
  count = var.enable_database_subnets ? length(aws_subnet.database) : 0

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database[0].id
}

# VPC Flow Logs is disabled for this POC
resource "aws_flow_log" "vpc" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.flow_log[0].arn
  log_destination = aws_cloudwatch_log_group.flow_log[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.environment}-vpc-flow-logs"
  })
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.environment}/flow-logs"
  retention_in_days = var.flow_log_retention_days

  tags = local.common_tags
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.environment}-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.environment}-vpc-flow-log-policy"
  role = aws_iam_role.flow_log[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

#security 
#Database subnets rely on route table isolation (no internet routes) + Security Groups
#Private subnets have NACL filtering + NAT routing + Security Groups
#Public subnets have NACL filtering + IGW routing + Security Groups
#NACLs are stateless - they don't automatically allow return traffic like Security Groups do.


# Network ACLs
resource "aws_network_acl" "private" {
  count = var.enable_network_acls ? 1 : 0

  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  # Allow all inbound traffic within VPC CIDR (10.0.0.0/16)
  # Enables: Cross-AZ communication, subnet-to-subnet traffic, multi-tier app connectivity
  # Does NOT allow: External internet traffic (handled by other rules)
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Allow outbound traffic to VPC
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Allow outbound HTTPS to any destination (VPC endpoints, AWS APIs, external services)
  # Covers: VPC endpoints (S3, DynamoDB), AWS service APIs, third-party HTTPS APIs
  # Routing: VPC endpoints stay internal, internet destinations via NAT/IGW
  # Note: AWS automatically adds route 10.0.0.0/16 → local to ALL route tables in this VPC
  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment}-private-nacl"
  })
}

resource "aws_network_acl" "public" {
  count = var.enable_network_acls && var.enable_public_subnets ? 1 : 0

  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  # Allow inbound HTTP/HTTPS from internet
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  
  # This rule allows respone traffic to ephemeral ports in the range 1024 - 65535 from anywhere
  # Risk: External systems could initiate connections to your ephemeral ports
  # Mitigation: Security Groups provide instance-level protection
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow all outbound
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(local.common_tags, {
    Name = "${var.environment}-public-nacl"
  })
}

