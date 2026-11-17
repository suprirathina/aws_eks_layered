#####################################
# ALB MODULE - IAM CONFIGURATIONS
#####################################

# IAM Role for ALB Log Processor Lambda
resource "aws_iam_role" "alb_log_processor" {
  count = var.enable_access_logs && var.enable_cloudwatch_integration ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-alb-log-processor"
  
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
  
  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-alb-log-processor"
    Module = "alb"
    Type   = "iam-role"
  })
}

# IAM Policy for ALB Log Processor Lambda
resource "aws_iam_role_policy" "alb_log_processor" {
  count = var.enable_access_logs && var.enable_cloudwatch_integration ? 1 : 0
  
  name = "ALBLogProcessorPolicy"
  role = aws_iam_role.alb_log_processor[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream", 
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-${var.environment}-alb-log-processor",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-${var.environment}-alb-log-processor:*",
          aws_cloudwatch_log_group.alb_metrics[0].arn,
          "${aws_cloudwatch_log_group.alb_metrics[0].arn}:*"
        ]
      },
      {
        Sid    = "S3AccessLogsRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.alb_logs[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:ExistingObjectTag/Source" = "ALB"
          }
        }
      },
      {
        Sid    = "S3BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.alb_logs[0].arn
      },
      {
        Sid    = "CloudWatchMetricsAccess"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "ALB/ProcessedMetrics"
          }
        }
      },
      {
        Sid    = "CloudWatchInsightsAccess"
        Effect = "Allow"
        Action = [
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:GetLogRecord"
        ]
        Resource = [
          aws_cloudwatch_log_group.alb_metrics[0].arn,
          "${aws_cloudwatch_log_group.alb_metrics[0].arn}:*"
        ]
      }
    ]
  })
}

# Attach AWS managed policy for basic Lambda execution
resource "aws_iam_role_policy_attachment" "alb_log_processor_basic" {
  count = var.enable_access_logs && var.enable_cloudwatch_integration ? 1 : 0
  
  role       = aws_iam_role.alb_log_processor[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Optional: Attach AWS X-Ray tracing policy for Lambda debugging
resource "aws_iam_role_policy_attachment" "alb_log_processor_xray" {
  count = var.enable_access_logs && var.enable_cloudwatch_integration && var.enable_lambda_tracing ? 1 : 0
  
  role       = aws_iam_role.alb_log_processor[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Data sources for IAM policy construction
data "aws_caller_identity" "current" {
  count = var.enable_access_logs && var.enable_cloudwatch_integration ? 1 : 0
}

#####################################
# S3 BUCKET POLICY FOR ALB ACCESS LOGS
#####################################

# S3 bucket policy to allow ALB to write access logs
resource "aws_s3_bucket_policy" "alb_logs" {
  count = var.enable_access_logs ? 1 : 0
  
  bucket = aws_s3_bucket.alb_logs[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "ALBAccessLogsPolicy"
    Statement = [
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main[0].arn
        }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main[0].arn
        }
        Action = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs[0].arn
      },
      {
        Sid    = "DenyInsecureConnections"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.alb_logs[0].arn,
          "${aws_s3_bucket.alb_logs[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
  
  depends_on = [aws_s3_bucket_public_access_block.alb_logs]
}

#####################################
# LAMBDA PERMISSIONS
#####################################

# Lambda permission for S3 to invoke the function
resource "aws_lambda_permission" "alb_log_processor_s3" {
  count = var.enable_access_logs && var.enable_cloudwatch_integration ? 1 : 0
  
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alb_log_processor[0].function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.alb_logs[0].arn
}

# Optional: CloudWatch Events permission for scheduled processing
resource "aws_lambda_permission" "alb_log_processor_events" {
  count = var.enable_access_logs && var.enable_cloudwatch_integration && var.enable_scheduled_processing ? 1 : 0
  
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alb_log_processor[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.alb_log_processing[0].arn
}