# IAM Roles and Policies for Observability Services
# Service roles for Grafana, Prometheus, FluentBit, and log processing

# Grafana Service Role
resource "aws_iam_role" "grafana" {
  count = var.enable_grafana ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-grafana-role"
  path = "/observability/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "grafana.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${var.environment}-${var.cluster_name}-grafana-role"
    Purpose = "grafana-service"
  })
}

resource "aws_iam_role_policy" "grafana" {
  count = var.enable_grafana ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-grafana-policy"
  role = aws_iam_role.grafana[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetInsightRuleReport"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:GetLogRecord"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "tag:GetResources"
        ]
        Resource = "*"
      }
    ]
  })
}

# Additional Grafana policy for Prometheus data source
resource "aws_iam_role_policy" "grafana_prometheus" {
  count = var.enable_grafana && var.enable_prometheus ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-grafana-prometheus-policy"
  role = aws_iam_role.grafana[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aps:ListWorkspaces",
          "aps:DescribeWorkspace",
          "aps:QueryMetrics",
          "aps:GetLabels",
          "aps:GetSeries",
          "aps:GetMetricMetadata"
        ]
        Resource = var.enable_prometheus ? aws_prometheus_workspace.main[0].arn : "*"
      }
    ]
  })
}

# CloudWatch Container Insights Role (IRSA)
resource "aws_iam_role" "cloudwatch_agent" {
  count = var.enable_container_insights ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-cloudwatch-agent"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${var.oidc_issuer_url}:sub" = "system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"
            "${var.oidc_issuer_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.environment}-${var.cluster_name}-cloudwatch-agent"
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  count = var.enable_container_insights ? 1 : 0

  role       = aws_iam_role.cloudwatch_agent[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "cloudwatch_agent_additional" {
  count = var.enable_container_insights ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-cloudwatch-agent-additional"
  role = aws_iam_role.cloudwatch_agent[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# Prometheus Remote Write Role (IRSA)
resource "aws_iam_role" "prometheus_remote_write" {
  count = var.enable_prometheus ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-prometheus-remote-write"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${var.oidc_issuer_url}:sub" = "system:serviceaccount:prometheus:prometheus-server"
            "${var.oidc_issuer_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.environment}-${var.cluster_name}-prometheus-remote-write"
  })
}

resource "aws_iam_role_policy" "prometheus_remote_write" {
  count = var.enable_prometheus ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-prometheus-remote-write-policy"
  role = aws_iam_role.prometheus_remote_write[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aps:RemoteWrite",
          "aps:QueryMetrics",
          "aps:GetSeries",
          "aps:GetLabels",
          "aps:GetMetricMetadata"
        ]
        Resource = aws_prometheus_workspace.main[0].arn
      }
    ]
  })
}

# FluentBit Role (IRSA)
resource "aws_iam_role" "fluentbit" {
  count = var.enable_fluentbit ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-fluentbit"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${var.oidc_issuer_url}:sub" = "system:serviceaccount:amazon-cloudwatch:fluent-bit"
            "${var.oidc_issuer_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.environment}-${var.cluster_name}-fluentbit"
  })
}

resource "aws_iam_role_policy" "fluentbit" {
  count = var.enable_fluentbit ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-fluentbit-policy"
  role = aws_iam_role.fluentbit[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = aws_kinesis_firehose_delivery_stream.logs[0].arn
      }
    ]
  })
}

# Kinesis Firehose Delivery Role
resource "aws_iam_role" "firehose" {
  count = var.enable_fluentbit ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-firehose-delivery-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.environment}-${var.cluster_name}-firehose-delivery-role"
  })
}

resource "aws_iam_role_policy" "firehose" {
  count = var.enable_fluentbit ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-firehose-delivery-policy"
  role = aws_iam_role.firehose[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.observability_logs[0].arn,
          "${aws_s3_bucket.observability_logs[0].arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:GetFunctionConfiguration"
        ]
        Resource = aws_lambda_function.log_processor[0].arn
      },
      {
        Effect = "Allow"
        Action = [
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
        Resource = var.logs_kms_key_id != null ? [var.logs_kms_key_id] : []
      }
    ]
  })
}

# Lambda Execution Role for Log Processing
resource "aws_iam_role" "log_processor" {
  count = var.enable_fluentbit ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-log-processor-role"

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
    Name = "${var.environment}-${var.cluster_name}-log-processor-role"
  })
}

resource "aws_iam_role_policy_attachment" "log_processor_basic" {
  count = var.enable_fluentbit ? 1 : 0

  role       = aws_iam_role.log_processor[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "log_processor" {
  count = var.enable_fluentbit ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-log-processor-policy"
  role = aws_iam_role.log_processor[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = aws_kinesis_firehose_delivery_stream.logs[0].arn
      }
    ]
  })
}

# ADOT (AWS Distro for OpenTelemetry) Collector Role
resource "aws_iam_role" "adot_collector" {
  count = var.enable_adot_collector ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-adot-collector"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${var.oidc_issuer_url}:sub" = "system:serviceaccount:opentelemetry-operator-system:adot-collector"
            "${var.oidc_issuer_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.environment}-${var.cluster_name}-adot-collector"
  })
}

resource "aws_iam_role_policy" "adot_collector" {
  count = var.enable_adot_collector ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-adot-collector-policy"
  role = aws_iam_role.adot_collector[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "aps:RemoteWrite",
          "aps:QueryMetrics",
          "aps:GetSeries",
          "aps:GetLabels",
          "aps:GetMetricMetadata"
        ]
        Resource = var.enable_prometheus ? aws_prometheus_workspace.main[0].arn : "*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# EventBridge Role for Observability Events
resource "aws_iam_role" "eventbridge_observability" {
  count = var.enable_observability_events ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-eventbridge-observability"

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
    Name = "${var.environment}-${var.cluster_name}-eventbridge-observability"
  })
}

resource "aws_iam_role_policy" "eventbridge_observability" {
  count = var.enable_observability_events ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-eventbridge-observability-policy"
  role = aws_iam_role.eventbridge_observability[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          for topic in aws_sns_topic.alerts : topic.arn
        ]
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

# Cross-Account Monitoring Role (for centralized monitoring account)
resource "aws_iam_role" "cross_account_monitoring" {
  count = var.enable_cross_account_monitoring ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-cross-account-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.monitoring_account_trusted_principals
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.monitoring_external_id
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.environment}-${var.cluster_name}-cross-account-monitoring"
  })
}

resource "aws_iam_role_policy" "cross_account_monitoring" {
  count = var.enable_cross_account_monitoring ? 1 : 0

  name = "${var.environment}-${var.cluster_name}-cross-account-monitoring-policy"
  role = aws_iam_role.cross_account_monitoring[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "logs:Describe*",
          "logs:Get*",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "aps:ListWorkspaces",
          "aps:DescribeWorkspace",
          "aps:QueryMetrics",
          "aps:GetLabels",
          "aps:GetSeries",
          "aps:GetMetricMetadata"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:BatchGetTraces",
          "xray:GetServiceGraph",
          "xray:GetTimeSeriesServiceStatistics",
          "xray:GetTraceSummaries"
        ]
        Resource = "*"
      }
    ]
  })
}