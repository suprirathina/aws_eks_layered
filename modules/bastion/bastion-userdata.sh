#!/bin/bash
# Bastion Host User Data - Install kubectl and configure EKS access
# This script runs on first boot to setup the bastion host

# Update system
yum update -y

# Install kubectl
curl -o kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.31.0/2024-01-04/bin/linux/amd64/kubectl
chmod +x ./kubectl
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin
sudo cp ./kubectl /usr/local/bin/

# Install AWS CLI v2 (if not already present)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
yum install -y unzip
unzip awscliv2.zip
sudo ./aws/install

# Install session manager plugin (for SSH over Systems Manager)
yum install -y https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm

# Install git for future use
yum install -y git

# Configure kubectl for EKS cluster
aws eks update-kubeconfig --region ${region} --name ${cluster_name}

# Create helpful aliases
echo 'alias k=kubectl' >> /home/ec2-user/.bashrc
echo 'alias kgp="kubectl get pods"' >> /home/ec2-user/.bashrc
echo 'alias kgs="kubectl get services"' >> /home/ec2-user/.bashrc
echo 'alias kgn="kubectl get nodes"' >> /home/ec2-user/.bashrc

# Create welcome message
cat > /etc/motd << 'EOF'
=====================================
   SECURE-APP MICRO POC BASTION
=====================================

This bastion host provides secure access to:
- EKS Cluster: ${cluster_name}
- Region: ${region}

Quick Commands:
- kubectl get nodes
- kubectl get pods -A
- k get svc (alias for kubectl)

Reference Architecture Features:
✓ Secure jump box access
✓ EKS cluster management
✓ Private subnet connectivity

=====================================
EOF

# Set proper permissions
chown -R ec2-user:ec2-user /home/ec2-user/.kube 2>/dev/null || true

# Log completion
echo "$(date): Bastion host setup completed" >> /var/log/bastion-setup.log