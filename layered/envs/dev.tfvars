# DEV environment values. EXAMPLE values: adjust before use.
# Same Terraform code as every other environment; only these values differ.
# Layers, in apply order: 00-baseline, 10-network, 15-vpc-endpoints, 20-cluster, 30-apps, 40-observability
# Cost: 15-vpc-endpoints (Interface endpoints) and 20-cluster (EKS control plane, roughly $73/month) are billed
# by the hour and will exceed a $20/month target. Start with 00-baseline and 10-network.

project_name = "secure-app"
region       = "us-east-1"

# Which environment these values describe. Used in resource names and in the state key of every layer.
environment = "dev"

# Budget monitoring
daily_cost_limit  = "1"           # Alert if over $1/day (about $20/month)
cost_alert_emails = []            # Add your email: ["you@company.com"]

#####################################
# IAM MODULE CONFIGURATION
#####################################

enable_default_permission_sets = true
enable_default_eks_roles       = true

# Required (no default). Replace with the values of the dev account.
identity_center_instance_arn = "REPLACE-with-identity-center-instance-arn"
poc_account_id               = "REPLACE-with-dev-account-id"

permission_sets = {}

#####################################
# BASTION
#####################################

bastion_allowed_cidrs = ["REPLACE-with-your-ip/32"]   # Never 0.0.0.0/0 outside a throwaway POC
# ec2_key_pair_name   = "REPLACE-with-key-pair-name"

#####################################
# LAYERED LAYOUT SETTINGS
#####################################

# Bucket and region where all layers keep their state (must match envs/dev.backend.hcl)
state_bucket = "REPLACE-with-dev-tfstate-bucket"
state_region = "us-east-1"

#####################################
# DECLARED IN THE LAYERS BUT NOT WIRED INTO THE MODULE CALLS YET (no effect today)
# The module calls still hardcode these values. Wire them in, then set them per environment.
#####################################
# alb_enable_access_logs        = false
# ecr_enable_image_scanning     = true
# monitoring_log_retention_days = 7
# vpc_endpoints_enable_logging  = false
