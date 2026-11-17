# Observability Module Outputs

# CloudWatch Log Groups
output "container_insights_log_groups" {
  description = "Container Insights log group information"
  value = var.enable_container_insights ? {
    for name, lg in aws_cloudwatch_log_group.container_insights : name => {
      name = lg.name
      arn  = lg.arn
    }
  } : {}
}

output "application_log_groups" {
  description = "Application log group information"
  value = {
    for name, lg in aws_cloudwatch_log_group.application_logs : name => {
      name = lg.name
      arn  = lg.arn
    }
  }
}

# CloudWatch Dashboards
output "dashboard_urls" {
  description = "URLs to CloudWatch dashboards"
  value = {
    for name, dashboard in aws_cloudwatch_dashboard.dashboards : name => 
      "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${dashboard.dashboard_name}"
  }
}

output "dashboard_names" {
  description = "Names of created CloudWatch dashboards"
  value = {
    for name, dashboard in aws_cloudwatch_dashboard.dashboards : name => dashboard.dashboard_name
  }
}

# CloudWatch Alarms
output "metric_alarms" {
  description = "CloudWatch metric alarm information"
  value = {
    for name, alarm in aws_cloudwatch_metric_alarm.alarms : name => {
      name = alarm.alarm_name
      arn  = alarm.arn
    }
  }
}

output "composite_alarms" {
  description = "CloudWatch composite alarm information"
  value = {
    for name, alarm in aws_cloudwatch_composite_alarm.composite_alarms : name => {
      name = alarm.alarm_name
      arn  = alarm.arn
    }
  }
}

# SNS Topics and Subscriptions
output "sns_topics" {
  description = "SNS topic information for alerts"
  value = {
    for name, topic in aws_sns_topic.alert_topics : name => {
      name = topic.name
      arn  = topic.arn
    }
  }
}

output "sns_subscriptions" {
  description = "SNS subscription information"
  value = {
    for name, sub in aws_sns_topic_subscription.alert_subscriptions : name => {
      arn      = sub.arn
      protocol = sub.protocol
      endpoint = sub.endpoint
    }
  }
}

# Log Metric Filters
output "log_metric_filters" {
  description = "CloudWatch log metric filter information"
  value = {
    for name, filter in aws_cloudwatch_log_metric_filter.metric_filters : name => {
      name           = filter.name
      log_group_name = filter.log_group_name
      pattern        = filter.pattern
    }
  }
}

# CloudWatch Insights Queries
output "insights_queries" {
  description = "CloudWatch Insights query definitions"
  value = {
    for name, query in aws_cloudwatch_query_definition.query_definitions : name => {
      name         = query.name
      query_string = query.query_string
    }
  }
}

# Synthetics Canaries
output "synthetics_canaries" {
  description = "CloudWatch Synthetics canary information"
  value = {
    for name, canary in aws_synthetics_canary.canaries : name => {
      name   = canary.name
      id     = canary.id
      status = canary.status
    }
  }
}

# Application Insights
output "application_insights" {
  description = "Application Insights applications"
  value = {
    for name, app in aws_applicationinsights_application.application_insights : name => {
      name = app.resource_group_name
      arn  = app.arn
    }
  }
}

# X-Ray Sampling Rules
output "xray_sampling_rules" {
  description = "X-Ray sampling rule information"
  value = {
    for name, rule in aws_xray_sampling_rule.sampling_rules : name => {
      name = rule.rule_name
      arn  = rule.arn
    }
  }
}

# EventBridge Rules
output "eventbridge_rules" {
  description = "EventBridge rule information"
  value = {
    for name, rule in aws_cloudwatch_event_rule.custom_events : name => {
      name = rule.name
      arn  = rule.arn
    }
  }
}

# Monitoring URLs and Access Information
output "monitoring_access" {
  description = "URLs and access information for monitoring resources"
  value = {
    cloudwatch_console = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}"
    xray_console      = "https://${data.aws_region.current.name}.console.aws.amazon.com/xray/home?region=${data.aws_region.current.name}"
    insights_console  = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#logsV2:logs-insights"
  }
}

# Configuration Summary
output "configuration_summary" {
  description = "Summary of observability module configuration"
  value = {
    container_insights_enabled    = var.enable_container_insights
    container_insights_log_groups = length(aws_cloudwatch_log_group.container_insights)
    application_log_groups       = length(aws_cloudwatch_log_group.application_logs)
    dashboards                   = length(aws_cloudwatch_dashboard.dashboards)
    metric_alarms               = length(aws_cloudwatch_metric_alarm.alarms)
    composite_alarms            = length(aws_cloudwatch_composite_alarm.composite_alarms)
    sns_topics                  = length(aws_sns_topic.alert_topics)
    sns_subscriptions           = length(aws_sns_topic_subscription.alert_subscriptions)
    log_metric_filters          = length(aws_cloudwatch_log_metric_filter.metric_filters)
    insights_queries            = length(aws_cloudwatch_query_definition.query_definitions)
    synthetics_canaries         = length(aws_synthetics_canary.canaries)
    application_insights        = length(aws_applicationinsights_application.application_insights)
    xray_sampling_rules         = length(aws_xray_sampling_rule.sampling_rules)
    eventbridge_rules           = length(aws_cloudwatch_event_rule.custom_events)
  }
}

# Cost Estimation
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown for observability resources"
  value = {
    log_ingestion_gb_estimated    = "Variable based on application logs"
    log_storage_cost_estimated    = "$${0.50 * var.cost_optimization.log_retention_days / 30} per GB"
    cloudwatch_alarms            = "$${length(aws_cloudwatch_metric_alarm.alarms) * 0.10}"
    cloudwatch_dashboards        = "$${length(aws_cloudwatch_dashboard.dashboards) * 3.00}"
    synthetics_canaries          = "$${length(aws_synthetics_canary.canaries) * 0.0012} per run"
    total_fixed_monthly_estimated = "$${length(aws_cloudwatch_metric_alarm.alarms) * 0.10 + length(aws_cloudwatch_dashboard.dashboards) * 3.00}"
  }
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}