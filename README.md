# EKS POC: reusable Terraform modules, deployed as layered stacks

A POC for an enterprise-style EKS platform on AWS (Java microservices). Expensive features are built but
switched off by default, so each environment turns on only what it needs and what its budget allows.

## Layout

```
modules/    reusable building blocks (vpc, vpc-endpoints, security, iam, eks, alb, ecr, secrets, bastion, observability, platform)
layered/    deployable layers, one Terraform root each, one state per layer per environment
  00-baseline  10-network  15-vpc-endpoints  20-cluster  30-apps  40-observability
  envs/       <env>.tfvars and <env>.backend.hcl for dev, staging, prod
```

One copy of the code serves every environment. An environment is only its two files in `layered/envs/`.
Details and commands: [layered/README.md](layered/README.md).

## Quick start (dev)

1. Create an S3 bucket for Terraform state. Put its name in `layered/envs/dev.backend.hcl` and in `state_bucket` in `layered/envs/dev.tfvars`.
2. Replace the `REPLACE-...` values in `layered/envs/dev.tfvars`.
3. Apply the layers in order, starting with `00-baseline` and `10-network`.

## Cost: read before applying

The POC target is under $20 a month. Prices below are from memory, so verify them in the AWS Pricing Calculator.

| Layer | Cost |
|---|---|
| `00-baseline`, `10-network` | Low. VPC, subnets and route tables are free, NAT is off by default. The security module may enable Config and Security Hub by default. Check its defaults first |
| `15-vpc-endpoints` | The S3 Gateway endpoint is free. Each Interface endpoint is billed per hour per AZ. Six of them can exceed the cost of a NAT Gateway |
| `20-cluster` | The EKS control plane alone is roughly $73 a month, which exceeds the $20 target on its own |
| `30-apps`, `40-observability` | ALB, bastion and CloudWatch resources are billed |

Set `daily_cost_limit` in `envs/<env>.tfvars` so the budget alert matches your real target.

## Known issues (found by running `terraform validate`, not yet fixed)

These modules were commented out before, so their errors were hidden. They are in `modules/`, not in the layers:

- `modules/security/variables.tf` line 49: a function call in a variable default (blocks `00-baseline`).
- `modules/vpc-endpoints/outputs.tf` line 153: invalid `$\${` escape (blocks `15-vpc-endpoints`).
- `modules/iam/default-permission-sets.tf` line 84: invalid expression (blocks `20-cluster`).
- `modules/alb/outputs.tf` line 117, `modules/ecr/outputs.tf` line 105, `modules/secrets/main.tf` line 97 (block `30-apps`).
- `40-observability` was not verified.
- `10-network` validates.

Other things to check in the security module: `aws_s3_bucket_encryption` is not a valid resource in AWS provider 5.x
(use `aws_s3_bucket_server_side_encryption_configuration`), and some `dynamic` blocks are used for plain arguments.

## Values that still say "micro"

A few strings inside the module calls still use the old micro wording (for example the secrets descriptions,
`jwt_issuer = "secure-app-micro"`, and the budget resource name `micro_poc_budget`). They work, but rename them
before using other environments.

## Git

```powershell
cd C:\Users\rathinasabapathys1\Documents\AWS\EKS_poc
git init -b main
git add .
git status          # check that no state files or secrets are staged
git commit -m "Layered Terraform stacks and modules"
git remote add origin <your-new-repo-url>
git push -u origin main
```

`.terraform.lock.hcl` files are committed on purpose. Add other platforms with
`terraform providers lock -platform=linux_amd64 -platform=windows_amd64` if CI runs on a different OS.
