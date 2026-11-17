# Backend settings shared by all layers of the "prod" environment.
# The state "key" is different for every layer, so it is passed separately at init time:
#   terraform init -reconfigure -backend-config=../envs/prod.backend.hcl -backend-config="key=prod/10-network/terraform.tfstate"
# Keep prod state in the prod account, in its own bucket.

bucket       = "REPLACE-with-prod-tfstate-bucket"
region       = "us-east-1"
encrypt      = true
use_lockfile = true   # S3 native state locking (no DynamoDB table needed). Remove if your Terraform is older than 1.10
