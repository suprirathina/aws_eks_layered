# IAM Roles and Policies for Security Services
# Service roles for Config, CloudTrail, and other security services

# Config Service Role
resource "aws_iam_role" "config" {
  count = var.enable_config ? 1 : 0

  name = "${var.environment}-aws-config-role"
  path = "/security/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${var.environment}-aws-config-role"
    Purpose = "config-service"
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  count = var.enable_config ? 1 : 0

  role       = aws_iam_role.config[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/ConfigRole"
}

# CloudTrail CloudWatch Logs Role
resource "aws_iam_role" "cloudtrail_logs" {
  count = var.enable_cloudtrail && var.cloudtrail_cloudwatch_logs ? 1 : 0

  name = "${var.environment}-cloudtrail-logs-role"
  path = "/security/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${var.environment}-cloudtrail-logs-role"
    Purpose = "cloudtrail-logging"
  })
}

resource "aws_iam_role_policy" "cloudtrail_logs" {
  count = var.enable_cloudtrail && var.cloudtrail_cloudwatch_logs ? 1 : 0

  name = "${var.environment}-cloudtrail-logs-policy"
  role = aws_iam_role.cloudtrail_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/aws/cloudtrail/${var.environment}:*"
      }
    ]
  })
}

# EventBridge Role for Security Events
resource "aws_iam_role" "eventbridge_security" {
  count = var.enable_security_events ? 1 : 0

  name = "${var.environment}-eventbridge-security-role"
  path = "/security/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${var.environment}-eventbridge-security-role"
    Purpose = "security-events"
  })
}

resource "aws_iam_role_policy" "eventbridge_security" {
  count = var.enable_security_events ? 1 : 0

  name = "${var.environment}-eventbridge-security-policy"
  role = aws_iam_role.eventbridge_security[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.enable_security_events ? aws_sns_topic.security_alerts[0].arn : "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda Execution Role for Security Automation
resource "aws_iam_role" "security_lambda" {
  count = var.enable_security_automation ? 1 : 0

  name = "${var.environment}-security-lambda-role"
  path = "/security/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${var.environment}-security-lambda-role"
    Purpose = "security-automation"
  })
}

resource "aws_iam_role_policy_attachment" "security_lambda_basic" {
  count = var.enable_security_automation ? 1 : 0

  role       = aws_iam_role.security_lambda[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "security_lambda" {
  count = var.enable_security_automation ? 1 : 0

  name = "${var.environment}-security-lambda-policy"
  role = aws_iam_role.security_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "guardduty:GetFindings",
          "guardduty:UpdateFindings",
          "securityhub:GetFindings",
          "securityhub:BatchUpdateFindings",
          "config:GetComplianceDetailsByConfigRule",
          "config:GetComplianceDetailsByResource",
          "sns:Publish",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.main["security-logs"].arn
        ]
      }
    ]
  })
}

# Inspector Assessment Role (if enabled)
resource "aws_iam_role" "inspector" {
  count = var.enable_inspector ? 1 : 0

  name = "${var.environment}-inspector-role"
  path = "/security/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "inspector2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${var.environment}-inspector-role"
    Purpose = "vulnerability-assessment"
  })
}

resource "aws_iam_role_policy_attachment" "inspector" {
  count = var.enable_inspector ? 1 : 0

  role       = aws_iam_role.inspector[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonInspector2ServiceRolePolicy"
}

# Security Incident Response Role
resource "aws_iam_role" "incident_response" {
  count = var.enable_incident_response_role ? 1 : 0

  name = "${var.environment}-incident-response-role"
  path = "/security/incident-response/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.incident_response_trusted_principals
        }
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
          NumericLessThan = {
            "aws:MultiFactorAuthAge" = "3600"  # 1 hour
          }
        }
      }
    ]
  })

  max_session_duration = 3600  # 1 hour

  tags = merge(local.common_tags, {
    Name    = "${var.environment}-incident-response-role"
    Purpose = "security-incident-response"
  })
}

resource "aws_iam_role_policy" "incident_response" {
  count = var.enable_incident_response_role ? 1 : 0

  name = "${var.environment}-incident-response-policy"
  role = aws_iam_role.incident_response[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "SecurityToolsAccess"
        Effect = "Allow"
        Action = [
          "guardduty:*",
          "securityhub:*",
          "inspector2:*",
          "config:*",
          "cloudtrail:*",
          "logs:*"
        ]
        Resource = "*"
      },
      {
        Sid = "ReadOnlyForensics"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "s3:GetObject",
          "s3:ListBucket",
          "iam:Get*",
          "iam:List*"
        ]
        Resource = "*"
      },
      {
        Sid = "EmergencyIsolation"
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:StopInstances"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = local.region
          }
        }
      },
      {
        Sid = "DenyDestructiveActions"
        Effect = "Deny"
        Action = [
          "ec2:TerminateInstances",
          "rds:DeleteDBInstance",
          "s3:DeleteBucket",
          "iam:DeleteRole",
          "iam:DeleteUser"
        ]
        Resource = "*"
      }
    ]
  })
}

# Cross-Account Security Audit Role
resource "aws_iam_role" "cross_account_audit" {
  count = var.enable_cross_account_audit ? 1 : 0

  name = "${var.environment}-cross-account-security-audit"
  path = "/security/audit/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.security_audit_trusted_accounts
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.security_audit_external_id
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${var.environment}-cross-account-security-audit"
    Purpose = "cross-account-security-audit"
  })
}

resource "aws_iam_role_policy_attachment" "cross_account_audit" {
  count = var.enable_cross_account_audit ? 1 : 0

  role       = aws_iam_role.cross_account_audit[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy" "cross_account_audit_enhanced" {
  count = var.enable_cross_account_audit ? 1 : 0

  name = "${var.environment}-cross-account-audit-enhanced"
  role = aws_iam_role.cross_account_audit[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "access-analyzer:*",
          "guardduty:Get*",
          "guardduty:List*",
          "securityhub:Get*",
          "securityhub:List*",
          "inspector2:List*",
          "inspector2:Get*",
          "inspector2:Describe*"
        ]
        Resource = "*"
      }
    ]
  })
}