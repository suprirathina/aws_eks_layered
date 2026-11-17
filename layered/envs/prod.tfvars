# PROD environment values. EXAMPLE values: adjust before use.
# Same Terraform code as every other environment; only these values differ.
# Layers to apply: 00-baseline, 10-network, 15-vpc-endpoints, 20-cluster, 30-apps, 40-observability
# Production should live in its own AWS account, with its own state bucket.

project_name = "secure-app"
region       = "us-east-1"

# Which environment these values describe. Used in resource names and in the state key of every layer.
environment = "prod"

# Budget monitoring
daily_cost_limit  = "100"         # Alert if over $100/day
cost_alert_emails = []            # Add your team list: ["platform-team@company.com"]

#####################################
# IAM MODULE CONFIGURATION
#####################################

enable_default_permission_sets = true
enable_default_eks_roles       = true

# Required (no default). Replace with the values of the prod account.
identity_center_instance_arn = "REPLACE-with-identity-center-instance-arn"
poc_account_id               = "REPLACE-with-prod-account-id"

permission_sets = {}

#####################################
# BASTION
#####################################

bastion_allowed_cidrs = ["REPLACE-with-corporate-cidr"]   # Never 0.0.0.0/0 in production
# ec2_key_pair_name   = "REPLACE-with-key-pair-name"

#####################################
# LAYERED LAYOUT SETTINGS
#####################################

# Bucket and region where all layers keep their state (must match envs/prod.backend.hcl)
state_bucket = "REPLACE-with-prod-tfstate-bucket"
state_region = "us-east-1"

#####################################
# DECLARED IN THE LAYERS BUT NOT WIRED INTO THE MODULE CALLS YET (no effect today)
# The module calls still hardcode these values. Wire them in, then set them per environment.
#####################################
# alb_enable_access_logs        = true
# ecr_enable_image_scanning     = true
# monitoring_log_retention_days = 90
# vpc_endpoints_enable_logging  = true
