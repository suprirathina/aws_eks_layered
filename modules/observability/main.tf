#####################################
# OBSERVABILITY MODULE - Enterprise Monitoring & Alerting
#####################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Container Insights Log Groups
resource "aws_cloudwatch_log_group" "container_insights" {
  for_each = var.enable_container_insights ? var.container_insights_log_groups : {}

  name              = "/aws/containerinsights/${var.cluster_name}/${each.key}"
  retention_in_days = each.value.retention_days
  kms_key_id        = each.value.kms_key_id

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-container-insights-${each.key}"
    Module      = "observability"
    Application = "monitoring"
  })
}

# Application Log Groups
resource "aws_cloudwatch_log_group" "application_logs" {
  for_each = var.application_log_groups

  name              = each.value.name
  retention_in_days = each.value.retention_days
  kms_key_id        = each.value.kms_key_id

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${each.key}-logs"
    Module      = "observability"
    Application = each.value.application
  })
}

# CloudWatch Dashboards
resource "aws_cloudwatch_dashboard" "dashboards" {
  for_each = var.dashboards

  dashboard_name = "${var.project_name}-${var.environment}-${each.key}"
  dashboard_body = jsonencode(each.value.body)

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-${each.key}-dashboard"
    Module = "observability"
  })
}

# CloudWatch Metric Alarms
resource "aws_cloudwatch_metric_alarm" "alarms" {
  for_each = var.metric_alarms

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}"
  alarm_description   = each.value.description
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = each.value.period
  statistic           = each.value.statistic
  threshold           = each.value.threshold
  treat_missing_data  = each.value.treat_missing_data
  
  # Actions
  alarm_actions             = each.value.alarm_actions
  ok_actions               = each.value.ok_actions
  insufficient_data_actions = each.value.insufficient_data_actions
  
  # Dimensions
  dimensions = each.value.dimensions

  # Extended statistic for percentiles
  extended_statistic = each.value.extended_statistic
  
  # Datapoints to alarm
  datapoints_to_alarm = each.value.datapoints_to_alarm

  tags = merge(var.common_tags, {
    Name     = "${var.project_name}-${var.environment}-${each.key}-alarm"
    Module   = "observability"
    Severity = each.value.severity
  })
}

# CloudWatch Composite Alarms
resource "aws_cloudwatch_composite_alarm" "composite_alarms" {
  for_each = var.composite_alarms

  alarm_name        = "${var.project_name}-${var.environment}-${each.key}"
  alarm_description = each.value.description
  alarm_rule        = each.value.alarm_rule
  actions_enabled   = each.value.actions_enabled
  
  alarm_actions             = each.value.alarm_actions
  ok_actions               = each.value.ok_actions
  insufficient_data_actions = each.value.insufficient_data_actions

  tags = merge(var.common_tags, {
    Name     = "${var.project_name}-${var.environment}-${each.key}-composite-alarm"
    Module   = "observability"
    Severity = each.value.severity
  })
}

# SNS Topics for Alerts
resource "aws_sns_topic" "alert_topics" {
  for_each = var.sns_topics

  name                        = "${var.project_name}-${var.environment}-${each.key}"
  display_name               = each.value.display_name
  fifo_topic                 = each.value.fifo_topic
  content_based_deduplication = each.value.content_based_deduplication

  # KMS encryption
  kms_master_key_id = each.value.kms_master_key_id

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-${each.key}-topic"
    Module = "observability"
  })
}

# SNS Topic Subscriptions
resource "aws_sns_topic_subscription" "alert_subscriptions" {
  for_each = var.sns_subscriptions

  topic_arn                       = aws_sns_topic.alert_topics[each.value.topic_key].arn
  protocol                        = each.value.protocol
  endpoint                        = each.value.endpoint
  confirmation_timeout_in_minutes = each.value.confirmation_timeout_in_minutes
  endpoint_auto_confirms          = each.value.endpoint_auto_confirms
  raw_message_delivery           = each.value.raw_message_delivery

  # Filter policy for selective message delivery
  filter_policy = each.value.filter_policy
}

# CloudWatch Log Metric Filters
resource "aws_cloudwatch_log_metric_filter" "metric_filters" {
  for_each = var.log_metric_filters

  name           = "${var.project_name}-${var.environment}-${each.key}"
  log_group_name = each.value.log_group_name
  pattern        = each.value.pattern

  metric_transformation {
    name          = each.value.metric_transformation.name
    namespace     = each.value.metric_transformation.namespace
    value         = each.value.metric_transformation.value
    default_value = each.value.metric_transformation.default_value
    unit          = each.value.metric_transformation.unit
  }
}

# CloudWatch Insights Query Definitions
resource "aws_cloudwatch_query_definition" "query_definitions" {
  for_each = var.insights_queries

  name            = "${var.project_name}-${var.environment}-${each.key}"
  log_group_names = each.value.log_group_names
  query_string    = each.value.query_string
}

# CloudWatch Synthetics Canaries (for application monitoring)
resource "aws_synthetics_canary" "canaries" {
  for_each = var.synthetics_canaries

  name                 = "${var.project_name}-${var.environment}-${each.key}"
  artifact_s3_location = each.value.artifact_s3_location
  execution_role_arn   = each.value.execution_role_arn
  handler              = each.value.handler
  zip_file            = each.value.zip_file
  runtime_version     = each.value.runtime_version

  # Schedule configuration
  schedule {
    expression          = each.value.schedule.expression
    duration_in_seconds = each.value.schedule.duration_in_seconds
  }

  # Run configuration
  run_config {
    timeout_in_seconds    = each.value.run_config.timeout_in_seconds
    memory_in_mb         = each.value.run_config.memory_in_mb
    active_tracing       = each.value.run_config.active_tracing
    environment_variables = each.value.run_config.environment_variables
  }

  # Failure retention
  failure_retention_period = each.value.failure_retention_period
  success_retention_period = each.value.success_retention_period

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-${each.key}-canary"
    Module = "observability"
  })
}

# Application Insights (for .NET, Java applications)
resource "aws_applicationinsights_application" "application_insights" {
  for_each = var.application_insights

  resource_group_name                = each.value.resource_group_name
  auto_config_enabled               = each.value.auto_config_enabled
  auto_create                       = each.value.auto_create
  cwe_monitor_enabled              = each.value.cwe_monitor_enabled
  ops_center_enabled               = each.value.ops_center_enabled

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-${each.key}-app-insights"
    Module = "observability"
  })
}

# X-Ray Tracing Configuration
resource "aws_xray_sampling_rule" "sampling_rules" {
  for_each = var.xray_sampling_rules

  rule_name      = "${var.project_name}-${var.environment}-${each.key}"
  priority       = each.value.priority
  version        = each.value.version
  reservoir_size = each.value.reservoir_size
  fixed_rate     = each.value.fixed_rate
  url_path       = each.value.url_path
  host           = each.value.host
  http_method    = each.value.http_method
  service_name   = each.value.service_name
  service_type   = each.value.service_type
  resource_arn   = each.value.resource_arn

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-${each.key}-xray-rule"
    Module = "observability"
  })
}

# EventBridge Rules for Custom Events
resource "aws_cloudwatch_event_rule" "custom_events" {
  for_each = var.eventbridge_rules

  name                = "${var.project_name}-${var.environment}-${each.key}"
  description         = each.value.description
  event_pattern       = each.value.event_pattern
  schedule_expression = each.value.schedule_expression
  state              = each.value.state

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-${each.key}-event-rule"
    Module = "observability"
  })
}

resource "aws_cloudwatch_event_target" "custom_event_targets" {
  for_each = var.eventbridge_targets

  rule      = aws_cloudwatch_event_rule.custom_events[each.value.rule_key].name
  target_id = each.key
  arn       = each.value.target_arn
  
  # SNS target configuration
  dynamic "sqs_target" {
    for_each = each.value.sqs_target != null ? [each.value.sqs_target] : []
    content {
      message_group_id = sqs_target.value.message_group_id
    }
  }

  # Lambda target configuration
  dynamic "input_transformer" {
    for_each = each.value.input_transformer != null ? [each.value.input_transformer] : []
    content {
      input_paths    = input_transformer.value.input_paths
      input_template = input_transformer.value.input_template
    }
  }
}