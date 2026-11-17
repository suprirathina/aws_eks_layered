# Observability Module Variables

# Required Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod, micro)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name for Container Insights"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Container Insights Configuration
variable "enable_container_insights" {
  description = "Enable Container Insights for EKS monitoring"
  type        = bool
  default     = true
}

variable "container_insights_log_groups" {
  description = "Container Insights log groups configuration"
  type = map(object({
    retention_days = number
    kms_key_id    = optional(string)
  }))
  default = {
    cluster = {
      retention_days = 3
      kms_key_id    = null
    }
    host = {
      retention_days = 3
      kms_key_id    = null
    }
    dataplane = {
      retention_days = 3
      kms_key_id    = null
    }
  }
}

# Application Log Groups
variable "application_log_groups" {
  description = "Application-specific log groups"
  type = map(object({
    name           = string
    retention_days = number
    kms_key_id    = optional(string)
    application   = string
  }))
  default = {}
}

# CloudWatch Dashboards
variable "dashboards" {
  description = "CloudWatch dashboards configuration"
  type = map(object({
    body = object({
      widgets = list(any)
    })
  }))
  default = {}
}

# CloudWatch Metric Alarms
variable "metric_alarms" {
  description = "CloudWatch metric alarms configuration"
  type = map(object({
    description         = string
    comparison_operator = string
    evaluation_periods  = string
    metric_name        = string
    namespace          = string
    period             = string
    statistic          = string
    threshold          = string
    treat_missing_data = optional(string, "missing")
    alarm_actions      = optional(list(string), [])
    ok_actions         = optional(list(string), [])
    insufficient_data_actions = optional(list(string), [])
    dimensions         = optional(map(string), {})
    extended_statistic = optional(string)
    datapoints_to_alarm = optional(number)
    severity           = optional(string, "medium")
  }))
  default = {}
}

# CloudWatch Composite Alarms
variable "composite_alarms" {
  description = "CloudWatch composite alarms configuration"
  type = map(object({
    description    = string
    alarm_rule     = string
    actions_enabled = optional(bool, true)
    alarm_actions  = optional(list(string), [])
    ok_actions     = optional(list(string), [])
    insufficient_data_actions = optional(list(string), [])
    severity       = optional(string, "high")
  }))
  default = {}
}

# SNS Topics and Subscriptions
variable "sns_topics" {
  description = "SNS topics for alerts"
  type = map(object({
    display_name                = optional(string)
    fifo_topic                 = optional(bool, false)
    content_based_deduplication = optional(bool, false)
    kms_master_key_id          = optional(string)
  }))
  default = {}
}

variable "sns_subscriptions" {
  description = "SNS topic subscriptions"
  type = map(object({
    topic_key                       = string
    protocol                        = string
    endpoint                        = string
    confirmation_timeout_in_minutes = optional(number, 1)
    endpoint_auto_confirms          = optional(bool, false)
    raw_message_delivery           = optional(bool, false)
    filter_policy                  = optional(string)
  }))
  default = {}
}

# Log Metric Filters
variable "log_metric_filters" {
  description = "CloudWatch log metric filters"
  type = map(object({
    log_group_name = string
    pattern        = string
    metric_transformation = object({
      name          = string
      namespace     = string
      value         = string
      default_value = optional(string, "0")
      unit          = optional(string, "Count")
    })
  }))
  default = {}
}

# CloudWatch Insights Queries
variable "insights_queries" {
  description = "CloudWatch Insights saved queries"
  type = map(object({
    log_group_names = list(string)
    query_string    = string
  }))
  default = {}
}

# CloudWatch Synthetics
variable "synthetics_canaries" {
  description = "CloudWatch Synthetics canaries for application monitoring"
  type = map(object({
    artifact_s3_location = string
    execution_role_arn   = string
    handler              = string
    zip_file            = string
    runtime_version     = string
    schedule = object({
      expression          = string
      duration_in_seconds = optional(number, 0)
    })
    run_config = object({
      timeout_in_seconds    = optional(number, 60)
      memory_in_mb         = optional(number, 960)
      active_tracing       = optional(bool, false)
      environment_variables = optional(map(string), {})
    })
    failure_retention_period = optional(number, 31)
    success_retention_period = optional(number, 31)
  }))
  default = {}
}

# Application Insights
variable "application_insights" {
  description = "AWS Application Insights configuration"
  type = map(object({
    resource_group_name = string
    auto_config_enabled = optional(bool, true)
    auto_create        = optional(bool, true)
    cwe_monitor_enabled = optional(bool, true)
    ops_center_enabled  = optional(bool, true)
  }))
  default = {}
}

# X-Ray Tracing
variable "xray_sampling_rules" {
  description = "X-Ray sampling rules for distributed tracing"
  type = map(object({
    priority       = number
    version        = optional(number, 1)
    reservoir_size = number
    fixed_rate     = number
    url_path       = optional(string, "*")
    host           = optional(string, "*")
    http_method    = optional(string, "*")
    service_name   = optional(string, "*")
    service_type   = optional(string, "*")
    resource_arn   = optional(string, "*")
  }))
  default = {}
}

# EventBridge Rules
variable "eventbridge_rules" {
  description = "EventBridge rules for custom monitoring events"
  type = map(object({
    description         = string
    event_pattern       = optional(string)
    schedule_expression = optional(string)
    state              = optional(string, "ENABLED")
  }))
  default = {}
}

variable "eventbridge_targets" {
  description = "EventBridge rule targets"
  type = map(object({
    rule_key   = string
    target_arn = string
    sqs_target = optional(object({
      message_group_id = string
    }))
    input_transformer = optional(object({
      input_paths    = map(string)
      input_template = string
    }))
  }))
  default = {}
}

# Cost Optimization Settings
variable "cost_optimization" {
  description = "Cost optimization settings for observability resources"
  type = object({
    log_retention_days        = optional(number, 3)
    enable_detailed_monitoring = optional(bool, false)
    metric_filter_sampling    = optional(number, 1.0)
  })
  default = {
    log_retention_days        = 3
    enable_detailed_monitoring = false
    metric_filter_sampling    = 1.0
  }
}