# Backend settings shared by all layers of the "staging" environment.
# The state "key" is different for every layer, so it is passed separately at init time:
#   terraform init -reconfigure -backend-config=../envs/staging.backend.hcl -backend-config="key=staging/10-network/terraform.tfstate"

bucket       = "REPLACE-with-staging-tfstate-bucket"
region       = "us-east-1"
encrypt      = true
use_lockfile = true   # S3 native state locking (no DynamoDB table needed). Remove if your Terraform is older than 1.10
