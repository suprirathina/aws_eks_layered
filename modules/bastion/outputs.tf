# Bastion Module Outputs

# Instance Information
output "instance_id" {
  description = "Bastion host instance ID"
  value       = aws_instance.bastion.id
}

output "public_ip" {
  description = "Bastion host public IP address"
  value       = aws_instance.bastion.public_ip
}

output "private_ip" {
  description = "Bastion host private IP address"
  value       = aws_instance.bastion.private_ip
}

output "elastic_ip" {
  description = "Bastion host Elastic IP (if enabled)"
  value       = var.use_elastic_ip ? aws_eip.bastion[0].public_ip : null
}

output "dns_name" {
  description = "Bastion host public DNS name"
  value       = aws_instance.bastion.public_dns
}

# Security Group Information
output "security_group_id" {
  description = "Security group ID for bastion host"
  value       = aws_security_group.bastion.id
}

# IAM Information
output "iam_role_arn" {
  description = "IAM role ARN for bastion host"
  value       = aws_iam_role.bastion.arn
}

output "instance_profile_name" {
  description = "Instance profile name for bastion host"
  value       = aws_iam_instance_profile.bastion.name
}

# Connection Information
output "ssh_command" {
  description = "SSH command to connect to bastion host"
  value       = "ssh -i ~/.ssh/${var.ec2_key_pair_name}.pem ec2-user@${var.use_elastic_ip ? aws_eip.bastion[0].public_ip : aws_instance.bastion.public_ip}"
}

output "ssm_command" {
  description = "AWS CLI command to connect via Session Manager"
  value       = "aws ssm start-session --target ${aws_instance.bastion.id} --region ${var.region}"
}

# AMI Information
output "ami_id" {
  description = "AMI ID used for bastion host"
  value       = aws_instance.bastion.ami
}

output "ami_name" {
  description = "AMI name used for bastion host"
  value       = data.aws_ami.amazon_linux.name
}