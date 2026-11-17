# Default Permission Sets for Common Access Patterns
# These provide standardized, least-privilege access patterns for enterprise use

locals {
  # Default permission sets configuration
  default_permission_sets = var.enable_default_permission_sets ? {
    
    # ReadOnly Access - Auditors, Compliance, Reporting
    "EKS-ReadOnlyAccess" = {
      description      = "Read-only access to EKS and supporting AWS services for auditing and compliance"
      session_duration = "PT4H"
      access_level     = "ReadOnly"
      
      aws_managed_policies = [
        "arn:aws:iam::aws:policy/ReadOnlyAccess",
        "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
      ]
      
      inline_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid = "EKSReadOnlyAccess"
            Effect = "Allow"
            Action = [
              "eks:DescribeCluster",
              "eks:ListClusters",
              "eks:DescribeNodegroup",
              "eks:ListNodegroups",
              "eks:DescribeFargateProfile",
              "eks:ListFargateProfiles",
              "eks:DescribeAddon",
              "eks:ListAddons",
              "eks:DescribeUpdate",
              "eks:ListUpdates",
              "eks:AccessKubernetesApi"
            ]
            Resource = "*"
          },
          {
            Sid = "KubernetesReadOnlyAccess"
            Effect = "Allow"
            Action = [
              "eks:AccessKubernetesApi"
            ]
            Resource = "*"
            Condition = {
              StringEquals = {
                "kubernetes.io/resource/verb" = ["get", "list", "watch"]
              }
            }
          }
        ]
      })
      
      account_assignments = []
    }

    # Developer Access - Application Developers
    "EKS-DeveloperAccess" = {
      description      = "Application developers - deploy and manage applications in EKS"
      session_duration = "PT8H"
      access_level     = "Developer"
      
      aws_managed_policies = []
      
      inline_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid = "EKSReadAccess"
            Effect = "Allow"
            Action = [
              "eks:DescribeCluster",
              "eks:ListClusters",
              "eks:AccessKubernetesApi",
              "eks:DescribeNodegroup",
              "eks:ListNodegroups",
              "eks:DescribeAddon",
              "eks:ListAddons"
            ]
            Resource = "*"
          },
          },
          {
            Sid = "ECRDeveloperAccess"
            Effect = "Allow"
            Action = [
              "ecr:GetAuthorizationToken",
              "ecr:BatchCheckLayerAvailability",
              "ecr:BatchGetImage",
              "ecr:GetDownloadUrlForLayer",
              "ecr:ListImages",
              "ecr:DescribeRepositories",
              "ecr:DescribeImages",
              "ecr:PutImage",
              "ecr:InitiateLayerUpload",
              "ecr:UploadLayerPart",
              "ecr:CompleteLayerUpload"
            ]
            Resource = "*"
          },
          {
            Sid = "CloudWatchLogsRead"
            Effect = "Allow"
            Action = [
              "logs:DescribeLogGroups",
              "logs:DescribeLogStreams",
              "logs:GetLogEvents",
              "logs:FilterLogEvents",
              "logs:StartQuery",
              "logs:StopQuery",
              "logs:GetQueryResults"
            ]
            Resource = "*"
          },
          {
            Sid = "SecretsManagerRead"
            Effect = "Allow"
            Action = [
              "secretsmanager:GetSecretValue",
              "secretsmanager:DescribeSecret"
            ]
            Resource = "arn:aws:secretsmanager:*:*:secret:*"
            Condition = {
              StringLike = {
                "secretsmanager:ResourceTag/Environment": ["dev", "staging", "micro"]
              }
            }
          },
          {
            Sid = "KubernetesAPIAccess"
            Effect = "Allow"
            Action = [
              "eks:AccessKubernetesApi"
            ]
            Resource = "*"
            Condition = {
              StringLike = {
                "kubernetes.io/resource/namespace": ["default", "kube-system", "dev-*", "staging-*"]
              }
            }
          }
        ]
      })
      
      account_assignments = [
	  {
        principal_id   = "642834c8-7051-70aa-7308-d10abaeada19"
        principal_type = "GROUP"  # or "USER"
        target_id      = "595898627793"
        target_type    = "AWS_ACCOUNT"
      }]
    }

    # DevOps Engineer Access - Infrastructure Management
    "EKS-DevOpsEngineer" = {
      description      = "DevOps engineers - EKS infrastructure and platform management"
      session_duration = "PT8H"
      access_level     = "DevOps"
      
      aws_managed_policies = []
      
      inline_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid = "EKSManagement"
            Effect = "Allow"
            Action = [
              "eks:*"
            ]
            Resource = "*"
          },
          {
            Sid = "ECRFullAccess"
            Effect = "Allow"
            Action = [
              "ecr:*"
            ]
            Resource = "*"
          },
          {
            Sid = "VPCNetworkingManagement"
            Effect = "Allow"
            Action = [
              "ec2:Describe*",
              "ec2:CreateSecurityGroup",
              "ec2:AuthorizeSecurityGroupIngress",
              "ec2:AuthorizeSecurityGroupEgress",
              "ec2:RevokeSecurityGroupIngress",
              "ec2:RevokeSecurityGroupEgress",
              "ec2:ModifySecurityGroupRules",
              "ec2:CreateTags",
              "elasticloadbalancing:*"
            ]
            Resource = "*"
          },
          {
            Sid = "CloudWatchAndLogging"
            Effect = "Allow"
            Action = [
              "logs:*",
              "cloudwatch:*",
              "application-autoscaling:*"
            ]
            Resource = "*"
          },
          {
            Sid = "IAMServiceRoleManagement"
            Effect = "Allow"
            Action = [
              "iam:GetRole",
              "iam:ListRoles",
              "iam:ListAttachedRolePolicies",
              "iam:ListRolePolicies",
              "iam:GetRolePolicy",
              "iam:PassRole"
            ]
            Resource = "*"
            Condition = {
              StringLike = {
                "iam:PassedToService": [
                  "eks.amazonaws.com",
                  "ec2.amazonaws.com",
                  "elasticloadbalancing.amazonaws.com"
                ]
              }
            }
          },
          {
            Sid = "SecretsManagerAccess"
            Effect = "Allow"
            Action = [
              "secretsmanager:*"
            ]
            Resource = "*"
          },
          {
            Sid = "DenyDestructiveEKSActions"
            Effect = "Deny"
            Action = [
              "eks:DeleteCluster"
            ]
            Resource = "*"
            Condition = {
              StringNotEquals = {
                "aws:PrincipalTag/Department" = "Platform"
              }
            }
          }
        ]
      })
      
      account_assignments = [{
        principal_id   = "1428a498-a051-70e4-f74b-ef95801f3883"
        principal_type = "GROUP"  # or "USER"
        target_id      = "595898627793"
        target_type    = "AWS_ACCOUNT"
      }]
    }

    # Administrator Access - Platform Team, SREs
    "EKS-AdminAccess" = {
      description      = "Full administrative access for platform team and SREs"
      session_duration = "PT4H"  # Shorter session for high privilege
      access_level     = "Administrator"
      
      aws_managed_policies = [
        "arn:aws:iam::aws:policy/AdministratorAccess"
      ]
      
      inline_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid = "RequireMFAForDestructiveActions"
            Effect = "Deny"
            Action = [
              "eks:DeleteCluster",
              "iam:DeleteRole",
              "ec2:TerminateInstances",
              "rds:DeleteDBInstance",
              "s3:DeleteBucket"
            ]
            Resource = "*"
            Condition = {
              Bool = {
                "aws:MultiFactorAuthPresent" = "false"
              }
            }
          },
          {
            Sid = "DenyRootAccess"
            Effect = "Deny"
            Action = "*"
            Resource = "*"
            Condition = {
              StringEquals = {
                "aws:userid" = "AIDA*"  # Deny root user actions
              }
            }
          }
        ]
      })
      
      account_assignments = []
    }

    # Security Auditor Access - Security Team
    "EKS-SecurityAuditor" = {
      description      = "Security auditor access for compliance and security assessment"
      session_duration = "PT8H"
      access_level     = "SecurityAudit"
      
      aws_managed_policies = [
        "arn:aws:iam::aws:policy/SecurityAudit",
        "arn:aws:iam::aws:policy/ReadOnlyAccess"
      ]
      
      inline_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid = "SecurityAuditEnhanced"
            Effect = "Allow"
            Action = [
              "access-analyzer:*",
              "guardduty:Get*",
              "guardduty:List*",
              "inspector:Describe*",
              "inspector:List*",
              "securityhub:Get*",
              "securityhub:List*",
              "config:Get*",
              "config:List*",
              "config:Describe*",
              "cloudtrail:Get*",
              "cloudtrail:List*",
              "cloudtrail:Describe*",
              "eks:AccessKubernetesApi"
            ]
            Resource = "*"
          },
          {
            Sid = "KubernetesSecurityAudit"
            Effect = "Allow"
            Action = [
              "eks:AccessKubernetesApi"
            ]
            Resource = "*"
            Condition = {
              StringEquals = {
                "kubernetes.io/resource/verb" = ["get", "list", "watch"]
              }
            }
          }
        ]
      })
      
      account_assignments = []
    }

    # Developer Access - Application Developers
    "EKS-DeveloperAccess" = {
      description      = "Developer access for application deployment and management within specific namespaces"
      session_duration = "PT8H"
      access_level     = "Developer"
      
      aws_managed_policies = [
        "arn:aws:iam::aws:policy/ReadOnlyAccess"
      ]
      
      inline_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid = "EKSClusterAccess"
            Effect = "Allow"
            Action = [
              "eks:DescribeCluster",
              "eks:ListClusters",
              "eks:AccessKubernetesApi"
            ]
            Resource = "*"
          },
          {
            Sid = "ECRReadAccess"
            Effect = "Allow"
            Action = [
              "ecr:GetAuthorizationToken",
              "ecr:BatchCheckLayerAvailability",
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage",
              "ecr:DescribeRepositories",
              "ecr:DescribeImages"
            ]
            Resource = "*"
          },
          {
            Sid = "ECRPushToDevRepos"
            Effect = "Allow"
            Action = [
              "ecr:InitiateLayerUpload",
              "ecr:UploadLayerPart",
              "ecr:CompleteLayerUpload",
              "ecr:PutImage"
            ]
            Resource = [
              "arn:aws:ecr:*:*:repository/*-dev",
              "arn:aws:ecr:*:*:repository/*-development",
              "arn:aws:ecr:*:*:repository/dev-*"
            ]
          },
          {
            Sid = "LogsAccess"
            Effect = "Allow"
            Action = [
              "logs:DescribeLogGroups",
              "logs:DescribeLogStreams",
              "logs:GetLogEvents",
              "logs:FilterLogEvents"
            ]
            Resource = "*"
          },
          {
            Sid = "SecretsManagerRead"
            Effect = "Allow"
            Action = [
              "secretsmanager:GetSecretValue",
              "secretsmanager:DescribeSecret"
            ]
            Resource = [
              "arn:aws:secretsmanager:*:*:secret:dev/*",
              "arn:aws:secretsmanager:*:*:secret:development/*"
            ]
          },
          {
            Sid = "DenyProductionAccess"
            Effect = "Deny"
            Action = "*"
            Resource = [
              "*prod*",
              "*production*"
            ]
          }
        ]
      })
      
      account_assignments = []
    }

    # Billing and Cost Management
    "BillingAccess" = var.default_permission_sets_config.create_billing_access ? {
      description      = "Billing and cost management access for finance team"
      session_duration = "PT4H"
      access_level     = "Billing"
      
      aws_managed_policies = [
        "arn:aws:iam::aws:policy/job-function/Billing"
      ]
      
      inline_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid = "CostOptimizationTools"
            Effect = "Allow"
            Action = [
              "ce:*",
              "cur:*",
              "aws-portal:*",
              "budgets:*",
              "pricing:*"
            ]
            Resource = "*"
          },
          {
            Sid = "ReadOnlyResourceAccess"
            Effect = "Allow"
            Action = [
              "ec2:Describe*",
              "rds:Describe*",
              "eks:Describe*",
              "eks:List*"
            ]
            Resource = "*"
          }
        ]
      })
      
      account_assignments = []
    } : null

  } : {}

  # Filter out null values and merge with user-defined permission sets
  all_permission_sets = merge(
    {
      for k, v in local.default_permission_sets : k => v
      if v != null
    },
    var.permission_sets
  )
}

# Override the main permission sets resource to use merged configuration
# This allows users to customize or add to default permission sets