# Layered stacks: one Terraform code copy for every environment

The root of this repo has `modules/` (reusable building blocks) and `layered/` (the deployable layers).
Each layer calls the modules with `source = "../../modules/..."`, so keep the two folders side by side.

```
layered/
  00-baseline/       security module + cost budget          (once per account/environment)
  10-network/        VPC
  15-vpc-endpoints/  private AWS endpoints (main cost item, deploy only when wanted)
  20-cluster/        IAM + EKS
  30-apps/           bastion, ALB, ECR, secrets
  40-observability/  monitoring
  envs/              one pair of files per environment: <env>.tfvars and <env>.backend.hcl
```

Each layer has its own state per environment: `s3://<bucket>/<env>/<layer>/terraform.tfstate`.
A layer reads what it needs from the layers below through `terraform_remote_state`, so apply them in order.
You do not comment modules out: just do not apply the layers you do not want yet.

## Deploy a layer (example: dev, 10-network)

Run from the layer folder. Backend values come from the env file, the state key from the command.

```powershell
cd layered\10-network
terraform init -reconfigure `
  -backend-config="../envs/dev.backend.hcl" `
  -backend-config="key=dev/10-network/terraform.tfstate"
terraform plan  -var-file="../envs/dev.tfvars" -out=dev.tfplan
terraform apply dev.tfplan
```

Order: 00-baseline, 10-network, 15-vpc-endpoints, 20-cluster, 30-apps, 40-observability. Destroy in reverse.

## Add an environment

`envs/` already has `dev`, `staging` and `prod` files with example values. For another environment:

1. Copy `envs/dev.tfvars` to `envs/<env>.tfvars` and change the values (`environment = "<env>"`, flags, limits).
2. Copy `envs/dev.backend.hcl` to `envs/<env>.backend.hcl` (a separate bucket or account is best for prod).
3. Run the same commands with `<env>` in the file names and in the `key`.

No Terraform code is copied or edited.

## Before the first apply

- Create the state bucket and put its name in `envs/<env>.backend.hcl` and `state_bucket` in `envs/<env>.tfvars`.
- Replace every `REPLACE-...` value in `envs/<env>.tfvars`.
- `envs/*.tfvars` is committed on purpose, so put only non-secret values in it. Secrets go in `TF_VAR_*` environment variables.
- One `<env>.tfvars` serves every layer, so Terraform prints a harmless warning for values a layer does not declare.
- `15-vpc-endpoints` creates Interface endpoints, and `20-cluster` creates an EKS cluster. Both are billed by the hour. Apply them only when you need them.
