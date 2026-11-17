# Default EKS IAM Roles - Enterprise Reference Architecture
# Centralized definition of standard EKS infrastructure and IRSA roles

locals {
  # Default EKS roles for enterprise environments
  default_eks_roles = var.enable_default_eks_roles ? {
    
    # ===============================================
    # BASIC EKS INFRASTRUCTURE ROLES
    # ===============================================
    
    # EKS Cluster Service Role - Required for EKS control plane
    "cluster-service" = {
      path                 = "/eks/"
      purpose              = "EKS cluster control plane operations"
      max_session_duration = 3600
      
      principal = {
        Service = ["eks.amazonaws.com"]
      }
      conditions = {}
      
      managed_policies = [
        "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
      ]
      inline_policies = {}
    }
    
    # EKS Node Group Role - Required for EC2 worker nodes
    "node-group" = {
      path                 = "/eks/"
      purpose              = "EKS worker node operations and container registry access"
      max_session_duration = 3600
      
      principal = {
        Service = ["ec2.amazonaws.com"]
      }
      conditions = {}
      
      managed_policies = [
        "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
        "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      ]
      inline_policies = {}
    }
    
    # ===============================================
    # ENTERPRISE IRSA ROLES
    # ===============================================
    
    # AWS Load Balancer Controller IRSA - Enterprise ingress management
    "aws-load-balancer-controller" = {
      path                 = "/irsa/"
      purpose              = "AWS Load Balancer Controller IRSA - Enterprise ingress management"
      max_session_duration = 3600
      
      principal = {
        # This will be set dynamically based on EKS OIDC provider
        Federated = "PLACEHOLDER_OIDC_PROVIDER_ARN"
      }
      conditions = {
        StringEquals = {
          "PLACEHOLDER_OIDC_PROVIDER:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller",
          "PLACEHOLDER_OIDC_PROVIDER:aud" = "sts.amazonaws.com"
        }
      }
      
      managed_policies = []
      inline_policies = {
        ALBIngressControllerIAMPolicy = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "iam:CreateServiceLinkedRole"
              ]
              Resource = "*"
              Condition = {
                StringEquals = {
                  "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
                }
              }
            },
            {
              Effect = "Allow"
              Action = [
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAddresses",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeVpcs",
                "ec2:DescribeVpcPeeringConnections",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeTags",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeListenerCertificates",
                "elasticloadbalancing:DescribeSSLPolicies",
                "elasticloadbalancing:DescribeRules",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetGroupAttributes",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:DescribeTags"
              ]
              Resource = "*"
            },
            {
              Effect = "Allow"
              Action = [
                "cognito-idp:DescribeUserPoolClient",
                "acm:ListCertificates",
                "acm:DescribeCertificate",
                "iam:ListServerCertificates",
                "iam:GetServerCertificate",
                "waf-regional:GetWebACL",
                "waf-regional:GetWebACLForResource",
                "waf-regional:AssociateWebACL",
                "waf-regional:DisassociateWebACL",
                "wafv2:GetWebACL",
                "wafv2:GetWebACLForResource",
                "wafv2:AssociateWebACL",
                "wafv2:DisassociateWebACL",
                "shield:DescribeProtection",
                "shield:GetSubscriptionState",
                "shield:DescribeSubscription",
                "shield:CreateProtection",
                "shield:DeleteProtection"
              ]
              Resource = "*"
            },
            {
              Effect = "Allow"
              Action = [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:CreateSecurityGroup",
                "ec2:CreateTags"
              ]
              Resource = "*"
            },
            {
              Effect = "Allow"
              Action = [
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateTargetGroup",
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:DeleteRule",
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:SetIpAddressType",
                "elasticloadbalancing:SetSecurityGroups",
                "elasticloadbalancing:SetSubnets",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyTargetGroupAttributes",
                "elasticloadbalancing:DeleteTargetGroup",
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:DeregisterTargets",
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
              ]
              Resource = "*"
            }
          ]
        })
      }
    }
    
    # External Secrets Operator IRSA - Enterprise secret synchronization
    "external-secrets-operator" = {
      path                 = "/irsa/"
      purpose              = "External Secrets Operator IRSA - Enterprise secret synchronization"
      max_session_duration = 3600
      
      principal = {
        Federated = "PLACEHOLDER_OIDC_PROVIDER_ARN"
      }
      conditions = {
        StringEquals = {
          "PLACEHOLDER_OIDC_PROVIDER:sub" = "system:serviceaccount:external-secrets:external-secrets-operator",
          "PLACEHOLDER_OIDC_PROVIDER:aud" = "sts.amazonaws.com"
        }
      }
      
      managed_policies = []
      inline_policies = {
        ExternalSecretsPolicy = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
              ]
              Resource = [
                "arn:${local.partition}:secretsmanager:${local.region}:${local.account_id}:secret:*"
              ]
              Condition = {
                StringEquals = {
                  "secretsmanager:ResourceTag/Environment" = var.environment
                }
              }
            },
            {
              Effect = "Allow"
              Action = [
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:GetParametersByPath"
              ]
              Resource = [
                "arn:${local.partition}:ssm:${local.region}:${local.account_id}:parameter/*"
              ]
            }
          ]
        })
      }
    }
    
    # EBS CSI Driver IRSA - Enterprise persistent volume management
    "ebs-csi-driver" = {
      path                 = "/irsa/"
      purpose              = "EBS CSI Driver IRSA - Enterprise persistent volume operations"
      max_session_duration = 3600
      
      principal = {
        Federated = "PLACEHOLDER_OIDC_PROVIDER_ARN"
      }
      conditions = {
        StringEquals = {
          "PLACEHOLDER_OIDC_PROVIDER:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa",
          "PLACEHOLDER_OIDC_PROVIDER:aud" = "sts.amazonaws.com"
        }
      }
      
      managed_policies = [
        "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      ]
      inline_policies = {}
    }
    
    # Cluster Autoscaler IRSA - Enterprise node scaling
    "cluster-autoscaler" = {
      path                 = "/irsa/"
      purpose              = "Cluster Autoscaler IRSA - Enterprise node group scaling"
      max_session_duration = 3600
      
      principal = {
        Federated = "PLACEHOLDER_OIDC_PROVIDER_ARN"
      }
      conditions = {
        StringEquals = {
          "PLACEHOLDER_OIDC_PROVIDER:sub" = "system:serviceaccount:kube-system:cluster-autoscaler",
          "PLACEHOLDER_OIDC_PROVIDER:aud" = "sts.amazonaws.com"
        }
      }
      
      managed_policies = []
      inline_policies = {
        ClusterAutoscalerPolicy = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeLaunchTemplateVersions",
                "ec2:DescribeImages",
                "ec2:GetInstanceTypesFromInstanceRequirements",
                "eks:DescribeNodegroup"
              ]
              Resource = "*"
            }
          ]
        })
      }
    }
    
    # Fluent Bit IRSA - Enterprise logging
    "fluent-bit" = {
      path                 = "/irsa/"
      purpose              = "Fluent Bit IRSA - Enterprise log forwarding to CloudWatch"
      max_session_duration = 3600
      
      principal = {
        Federated = "PLACEHOLDER_OIDC_PROVIDER_ARN"
      }
      conditions = {
        StringEquals = {
          "PLACEHOLDER_OIDC_PROVIDER:sub" = "system:serviceaccount:amazon-cloudwatch:fluent-bit",
          "PLACEHOLDER_OIDC_PROVIDER:aud" = "sts.amazonaws.com"
        }
      }
      
      managed_policies = []
      inline_policies = {
        FluentBitCloudWatchPolicy = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams"
              ]
              Resource = "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:*"
            }
          ]
        })
      }
    }
    
    # ADOT Collector IRSA - Enterprise observability  
    "adot-collector" = {
      path                 = "/irsa/"
      purpose              = "AWS Distro for OpenTelemetry Collector IRSA - Enterprise observability"
      max_session_duration = 3600
      
      principal = {
        Federated = "PLACEHOLDER_OIDC_PROVIDER_ARN"
      }
      conditions = {
        StringEquals = {
          "PLACEHOLDER_OIDC_PROVIDER:sub" = "system:serviceaccount:aws-otel-eks:adot-collector",
          "PLACEHOLDER_OIDC_PROVIDER:aud" = "sts.amazonaws.com"
        }
      }
      
      managed_policies = [
        "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess",
        "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess",
        "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      ]
      inline_policies = {}
    }
    
  } : {}

  # Merge default EKS roles with custom ones (custom takes precedence)
  all_eks_roles = merge(
    local.default_eks_roles,
    var.eks_roles
  )
}