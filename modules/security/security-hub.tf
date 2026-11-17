# Security Hub Configuration and Custom Insights
# Centralized security findings and compliance dashboard

# Security Hub Custom Insights
resource "aws_securityhub_insight" "custom_insights" {
  for_each = var.enable_security_hub ? var.security_hub_custom_insights : {}

  name      = each.key
  group_by_attribute = each.value.group_by_attribute

  dynamic "filters" {
    for_each = [each.value.filters]
    content {
      # Product ARN filters
      dynamic "product_arn" {
        for_each = try(filters.value.product_arn, [])
        content {
          comparison = product_arn.value.comparison
          value      = product_arn.value.value
        }
      }

      # Severity filters
      dynamic "severity_normalized" {
        for_each = try(filters.value.severity_normalized, [])
        content {
          gte = severity_normalized.value.gte
          lte = severity_normalized.value.lte
        }
      }

      # Compliance status filters
      dynamic "compliance_status" {
        for_each = try(filters.value.compliance_status, [])
        content {
          comparison = compliance_status.value.comparison
          value      = compliance_status.value.value
        }
      }

      # Resource type filters
      dynamic "resource_type" {
        for_each = try(filters.value.resource_type, [])
        content {
          comparison = resource_type.value.comparison
          value      = resource_type.value.value
        }
      }

      # Record state filters
      dynamic "record_state" {
        for_each = try(filters.value.record_state, [])
        content {
          comparison = record_state.value.comparison
          value      = record_state.value.value
        }
      }

      # Workflow status filters
      dynamic "workflow_status" {
        for_each = try(filters.value.workflow_status, [])
        content {
          comparison = workflow_status.value.comparison
          value      = workflow_status.value.value
        }
      }

      # Title filters
      dynamic "title" {
        for_each = try(filters.value.title, [])
        content {
          comparison = title.value.comparison
          value      = title.value.value
        }
      }

      # Resource ID filters
      dynamic "resource_id" {
        for_each = try(filters.value.resource_id, [])
        content {
          comparison = resource_id.value.comparison
          value      = resource_id.value.value
        }
      }
    }
  }
}

# Security Hub Action Targets (for automation)
resource "aws_securityhub_action_target" "remediation" {
  for_each = var.enable_security_hub ? var.security_hub_action_targets : {}

  name        = each.key
  identifier  = each.value.identifier
  description = each.value.description
}

# EventBridge Rules for Security Hub Findings
resource "aws_cloudwatch_event_rule" "security_hub_findings" {
  for_each = var.enable_security_hub && var.enable_security_events ? var.security_hub_event_rules : {}

  name        = "${var.environment}-${each.key}"
  description = each.value.description

  event_pattern = jsonencode({
    source        = ["aws.securityhub"]
    "detail-type" = each.value.detail_types
    detail = {
      findings = {
        Compliance = {
          Status = each.value.compliance_status
        }
        Severity = {
          Normalized = each.value.severity_range
        }
        ProductName = each.value.product_names
      }
    }
  })

  state = each.value.enabled ? "ENABLED" : "DISABLED"

  tags = merge(local.common_tags, {
    Name = "${var.environment}-${each.key}"
    Type = "security-event-rule"
  })
}

resource "aws_cloudwatch_event_target" "security_hub_sns" {
  for_each = var.enable_security_hub && var.enable_security_events ? var.security_hub_event_rules : {}

  rule      = aws_cloudwatch_event_rule.security_hub_findings[each.key].name
  target_id = "SecurityHubSNSTarget"
  arn       = aws_sns_topic.security_alerts[0].arn

  input_transformer {
    input_paths = {
      account     = "$.account"
      region      = "$.region"
      time        = "$.time"
      finding_id  = "$.detail.findings[0].Id"
      title       = "$.detail.findings[0].Title"
      description = "$.detail.findings[0].Description"
      severity    = "$.detail.findings[0].Severity.Normalized"
      compliance  = "$.detail.findings[0].Compliance.Status"
      resource    = "$.detail.findings[0].Resources[0].Id"
    }

    input_template = jsonencode({
      alert_type = "Security Hub Finding"
      environment = var.environment
      account_id = "<account>"
      region = "<region>"
      timestamp = "<time>"
      finding = {
        id = "<finding_id>"
        title = "<title>"
        description = "<description>"
        severity = "<severity>"
        compliance_status = "<compliance>"
        resource_id = "<resource>"
      }
      actions_required = each.value.actions_required
    })
  }
}

# SNS Topic for Security Alerts
resource "aws_sns_topic" "security_alerts" {
  count = var.enable_security_events ? 1 : 0

  name = "${var.environment}-security-alerts"

  kms_master_key_id = var.enable_log_encryption ? aws_kms_key.main["security-logs"].arn : null

  tags = merge(local.common_tags, {
    Name    = "${var.environment}-security-alerts"
    Purpose = "security-notifications"
  })
}

resource "aws_sns_topic_policy" "security_alerts" {
  count = var.enable_security_events ? 1 : 0

  arn = aws_sns_topic.security_alerts[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sns:Publish"
        Resource = aws_sns_topic.security_alerts[0].arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }
        }
      }
    ]
  })
}

# SNS Topic Subscriptions
resource "aws_sns_topic_subscription" "security_alerts" {
  for_each = var.enable_security_events ? var.security_alert_subscriptions : {}

  topic_arn = aws_sns_topic.security_alerts[0].arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint

  # Email confirmations
  confirmation_timeout_in_minutes = each.value.protocol == "email" ? 5 : null

  # Filter policy for targeted alerts
  dynamic "filter_policy" {
    for_each = each.value.filter_policy != null ? [each.value.filter_policy] : []
    content {
      filter_policy = jsonencode(filter_policy.value)
    }
  }
}

# Lambda for Security Automation
resource "aws_lambda_function" "security_automation" {
  count = var.enable_security_automation ? 1 : 0

  filename         = var.security_automation_lambda_zip
  function_name    = "${var.environment}-security-automation"
  role            = aws_iam_role.security_lambda[0].arn
  handler         = var.security_automation_lambda_handler
  runtime         = var.security_automation_lambda_runtime
  timeout         = 300

  # Environment variables
  environment {
    variables = merge(
      {
        ENVIRONMENT = var.environment
        SNS_TOPIC   = aws_sns_topic.security_alerts[0].arn
      },
      var.security_automation_lambda_env_vars
    )
  }

  # VPC configuration (if specified)
  dynamic "vpc_config" {
    for_each = var.security_automation_vpc_config != null ? [var.security_automation_vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tags = merge(local.common_tags, {
    Name    = "${var.environment}-security-automation"
    Purpose = "security-automation"
  })
}

# EventBridge trigger for security automation
resource "aws_cloudwatch_event_rule" "security_automation" {
  count = var.enable_security_automation ? 1 : 0

  name        = "${var.environment}-security-automation-trigger"
  description = "Trigger security automation lambda"

  event_pattern = jsonencode({
    source = ["aws.guardduty", "aws.securityhub", "aws.config"]
    "detail-type" = [
      "GuardDuty Finding",
      "Security Hub Findings - Imported",
      "Config Rules Compliance Change"
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.environment}-security-automation-trigger"
  })
}

resource "aws_cloudwatch_event_target" "security_automation" {
  count = var.enable_security_automation ? 1 : 0

  rule      = aws_cloudwatch_event_rule.security_automation[0].name
  target_id = "SecurityAutomationLambda"
  arn       = aws_lambda_function.security_automation[0].arn
}

resource "aws_lambda_permission" "security_automation" {
  count = var.enable_security_automation ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.security_automation[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.security_automation[0].arn
}

# Inspector v2 (if enabled)
resource "aws_inspector2_enabler" "inspector" {
  count = var.enable_inspector ? 1 : 0

  account_ids    = [local.account_id]
  resource_types = var.inspector_resource_types

  depends_on = [aws_iam_role.inspector]
}