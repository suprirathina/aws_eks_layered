#####################################
# BASTION MODULE - Secure Access Pattern
#####################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Security Group for Bastion Host
resource "aws_security_group" "bastion" {
  name_prefix = "${var.project_name}-${var.environment}-bastion-"
  vpc_id      = var.vpc_id
  description = "Security group for bastion host - secure access to EKS"

  # SSH access (configurable CIDR blocks)
  dynamic "ingress" {
    for_each = var.allowed_cidr_blocks
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "SSH access for bastion host"
    }
  }

  # All outbound traffic (for kubectl, package updates)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-bastion-sg"
    Module = "bastion"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Get latest Amazon Linux 2023 AMI with SSM Agent pre-installed
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]  # AL2023 includes SSM agent by default
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  # Ensure SSM agent is included
  filter {
    name   = "description"
    values = ["*SSM*", "*Systems Manager*", "*"]
  }
}

# IAM Role for Bastion Host (EKS access)
resource "aws_iam_role" "bastion" {
  name_prefix = "${var.project_name}-${var.environment}-bastion-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-bastion-role"
    Module = "bastion"
  })
}

# IAM Policy for EKS access and SSM
resource "aws_iam_role_policy" "bastion_eks_access" {
  name_prefix = "${var.project_name}-${var.environment}-bastion-eks-"
  role        = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = var.cluster_arn != "" ? [var.cluster_arn] : ["*"]
      }
    ]
  })
}

# Attach SSM managed policy for Systems Manager access
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile for Bastion
resource "aws_iam_instance_profile" "bastion" {
  name_prefix = "${var.project_name}-${var.environment}-bastion-"
  role        = aws_iam_role.bastion.name

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-bastion-profile"
    Module = "bastion"
  })
}

# Bastion Host EC2 Instance
resource "aws_instance" "bastion" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name              = var.ec2_key_pair_name
  subnet_id             = var.subnet_id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile  = aws_iam_instance_profile.bastion.name

  # Enable detailed monitoring for reference architecture
  monitoring = var.enable_detailed_monitoring

  # User data to install kubectl and AWS CLI
  user_data = var.user_data_script != "" ? base64encode(var.user_data_script) : base64encode(templatefile("${path.module}/bastion-userdata.sh", {
    cluster_name = var.cluster_name
    region       = var.region
  }))

  tags = merge(var.common_tags, {
    Name         = "${var.project_name}-${var.environment}-bastion"
    Module       = "bastion"
    AutoShutdown = var.auto_shutdown ? "true" : "false"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Elastic IP for Bastion (optional - for consistent access)
resource "aws_eip" "bastion" {
  count    = var.use_elastic_ip ? 1 : 0
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-bastion-eip"
    Module = "bastion"
  })

  depends_on = [aws_instance.bastion]
}