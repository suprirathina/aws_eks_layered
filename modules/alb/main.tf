#####################################
# ALB MODULE - Enterprise Ingress Pattern
#####################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  vpc_id      = var.vpc_id
  description = "Security group for Application Load Balancer"

  # HTTP access from allowed CIDR blocks
  dynamic "ingress" {
    for_each = var.enable_http ? var.allowed_cidr_blocks : []
    content {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "HTTP access"
    }
  }

  # HTTPS access from allowed CIDR blocks
  dynamic "ingress" {
    for_each = var.enable_https ? var.allowed_cidr_blocks : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "HTTPS access"
    }
  }

  # Custom port access (if specified)
  dynamic "ingress" {
    for_each = var.custom_ports
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
      description = ingress.value.description
    }
  }

  # All outbound traffic to targets
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-alb-sg"
    Module = "alb"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = var.internal ? var.private_subnet_ids : var.public_subnet_ids

  # Enable deletion protection
  enable_deletion_protection = var.enable_deletion_protection

  # Access logs (optional - costs extra)
  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = aws_s3_bucket.alb_logs[0].id
      prefix  = "alb-access-logs"
      enabled = true
    }
  }

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-alb"
    Module = "alb"
  })
}

# S3 bucket for ALB access logs (optional)
resource "aws_s3_bucket" "alb_logs" {
  count  = var.enable_access_logs ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-alb-logs-${random_id.bucket_suffix[0].hex}"

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-alb-logs"
    Module = "alb"
  })
}

# S3 bucket public access block 
resource "aws_s3_bucket_public_access_block" "alb_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "random_id" "bucket_suffix" {
  count       = var.enable_access_logs ? 1 : 0
  byte_length = 4
}

# S3 bucket lifecycle configuration for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  count  = var.enable_access_logs ? 1 : 0
  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    id     = "alb_logs_lifecycle"
    status = "Enabled"

    expiration {
      days = var.access_logs_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# Get ELB service account for access logs  
data "aws_elb_service_account" "main" {
  count = var.enable_access_logs ? 1 : 0
}

# Current region for console URLs
data "aws_region" "current" {}

#####################################
# CLOUDWATCH INTEGRATION
#####################################

# CloudWatch Log Group for processed ALB metrics
resource "aws_cloudwatch_log_group" "alb_metrics" {
  count = var.enable_access_logs && var.enable_cloudwatch_integration ? 1 : 0
  
  name              = var.cloudwatch_log_group_name != null ? var.cloudwatch_log_group_name : "/aws/alb/${var.project_name}/${var.environment}/metrics"
  retention_in_days = var.access_logs_retention_days
  
  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-alb-metrics"
    Module = "alb"
    Type   = "cloudwatch-log-group"
  })
}

# Lambda function to process ALB logs and send metrics to CloudWatch
resource "aws_lambda_function" "alb_log_processor" {
  count = var.enable_access_logs && var.enable_cloudwatch_integration ? 1 : 0
  
  filename         = "${path.module}/lambda/alb_log_processor.zip"
  function_name    = "${var.project_name}-${var.environment}-alb-log-processor"
  role            = aws_iam_role.alb_log_processor[0].arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  
  environment {
    variables = {
      LOG_GROUP_NAME = aws_cloudwatch_log_group.alb_metrics[0].name
      PROJECT_NAME   = var.project_name
      ENVIRONMENT    = var.environment
      METRICS_NAMESPACE = "ALB/ProcessedMetrics"
    }
  }
  
  # Optional X-Ray tracing
  tracing_config {
    mode = var.enable_lambda_tracing ? "Active" : "PassThrough"
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.alb_log_processor_basic,
    aws_cloudwatch_log_group.alb_metrics
  ]
  
  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-alb-log-processor"
    Module = "alb"
    Type   = "lambda-function"
  })
}

# S3 bucket notification to trigger Lambda on new ALB logs (immediate mode)
resource "aws_s3_bucket_notification" "alb_log_processor" {
  count = var.enable_access_logs && var.enable_cloudwatch_integration && var.lambda_trigger_mode == "immediate" ? 1 : 0
  
  bucket = aws_s3_bucket.alb_logs[0].id
  
  lambda_function {
    lambda_function_arn = aws_lambda_function.alb_log_processor[0].arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "AWSLogs/"
    filter_suffix       = ".gz"
  }
  
  depends_on = [aws_lambda_permission.alb_log_processor_s3]
}

# CloudWatch Event Rule for batched processing mode
resource "aws_cloudwatch_event_rule" "alb_log_processing" {
  count = var.enable_access_logs && var.enable_cloudwatch_integration && var.lambda_trigger_mode == "batched" ? 1 : 0
  
  name        = "${var.project_name}-${var.environment}-alb-log-processing"
  description = "Batched ALB log processing"
  
  # Configurable batch interval
  schedule_expression = "rate(${var.batch_processing_interval} minutes)"
  
  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-alb-log-processing"
    Module = "alb"
    Type   = "cloudwatch-event-rule"
  })
}

# CloudWatch Event Target for batched processing
resource "aws_cloudwatch_event_target" "alb_log_processing" {
  count = var.enable_access_logs && var.enable_cloudwatch_integration && var.lambda_trigger_mode == "batched" ? 1 : 0
  
  rule      = aws_cloudwatch_event_rule.alb_log_processing[0].name
  target_id = "ALBLogProcessorTarget"
  arn       = aws_lambda_function.alb_log_processor[0].arn
  
  input = jsonencode({
    mode     = "batched"
    bucket   = aws_s3_bucket.alb_logs[0].id
    interval = var.batch_processing_interval
  })
}

# Dynamic Target Groups
resource "aws_lb_target_group" "target_groups" {
  for_each = var.target_groups

  name     = "${var.project_name}-${var.environment}-${each.key}"
  port     = each.value.port
  protocol = each.value.protocol
  vpc_id   = var.vpc_id

  # Health check configuration
  health_check {
    enabled             = each.value.health_check.enabled
    healthy_threshold   = each.value.health_check.healthy_threshold
    interval            = each.value.health_check.interval
    matcher             = each.value.health_check.matcher
    path                = each.value.health_check.path
    port                = each.value.health_check.port
    protocol            = each.value.health_check.protocol
    timeout             = each.value.health_check.timeout
    unhealthy_threshold = each.value.health_check.unhealthy_threshold
  }

  # Target type for EKS pods
  target_type = each.value.target_type

  # Stickiness configuration (optional)
  dynamic "stickiness" {
    for_each = each.value.stickiness != null ? [each.value.stickiness] : []
    content {
      enabled         = stickiness.value.enabled
      type            = stickiness.value.type
      cookie_duration = stickiness.value.cookie_duration
    }
  }

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-${each.key}-tg"
    Module = "alb"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP Listener
resource "aws_lb_listener" "http" {
  count             = var.enable_http ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Default action based on configuration
  dynamic "default_action" {
    for_each = var.enable_https && var.redirect_http_to_https ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.default_target_group_key != "" && (!var.enable_https || !var.redirect_http_to_https) ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.target_groups[var.default_target_group_key].arn
    }
  }

  dynamic "default_action" {
    for_each = var.default_target_group_key == "" && (!var.enable_https || !var.redirect_http_to_https) ? [1] : []
    content {
      type = "fixed-response"
      fixed_response {
        content_type = "text/plain"
        message_body = "Not Found - ${var.project_name} ${var.environment}"
        status_code  = "404"
      }
    }
  }

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-http-listener"
    Module = "alb"
  })
}

# HTTPS Listener (optional - requires SSL certificate)
resource "aws_lb_listener" "https" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.ssl_certificate_arn

  # Default action
  dynamic "default_action" {
    for_each = var.default_target_group_key != "" ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.target_groups[var.default_target_group_key].arn
    }
  }

  dynamic "default_action" {
    for_each = var.default_target_group_key == "" ? [1] : []
    content {
      type = "fixed-response"
      fixed_response {
        content_type = "text/plain"
        message_body = "Not Found - ${var.project_name} ${var.environment}"
        status_code  = "404"
      }
    }
  }

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-https-listener"
    Module = "alb"
  })
}

# Dynamic Listener Rules
resource "aws_lb_listener_rule" "http_rules" {
  for_each = var.enable_http ? var.listener_rules : {}

  listener_arn = aws_lb_listener.http[0].arn
  priority     = each.value.priority

  action {
    type             = each.value.action.type
    target_group_arn = each.value.action.type == "forward" ? aws_lb_target_group.target_groups[each.value.action.target_group_key].arn : null

    dynamic "redirect" {
      for_each = each.value.action.type == "redirect" ? [each.value.action.redirect] : []
      content {
        port        = redirect.value.port
        protocol    = redirect.value.protocol
        status_code = redirect.value.status_code
        host        = redirect.value.host
        path        = redirect.value.path
        query       = redirect.value.query
      }
    }

    dynamic "fixed_response" {
      for_each = each.value.action.type == "fixed-response" ? [each.value.action.fixed_response] : []
      content {
        content_type = fixed_response.value.content_type
        message_body = fixed_response.value.message_body
        status_code  = fixed_response.value.status_code
      }
    }
  }

  dynamic "condition" {
    for_each = each.value.conditions
    content {
      dynamic "path_pattern" {
        for_each = condition.value.type == "path-pattern" ? [condition.value] : []
        content {
          values = path_pattern.value.values
        }
      }

      dynamic "host_header" {
        for_each = condition.value.type == "host-header" ? [condition.value] : []
        content {
          values = host_header.value.values
        }
      }
    }
  }

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-${each.key}-rule"
    Module = "alb"
  })
}

# HTTPS Listener Rules (if HTTPS is enabled)
resource "aws_lb_listener_rule" "https_rules" {
  for_each = var.enable_https ? var.listener_rules : {}

  listener_arn = aws_lb_listener.https[0].arn
  priority     = each.value.priority

  action {
    type             = each.value.action.type
    target_group_arn = each.value.action.type == "forward" ? aws_lb_target_group.target_groups[each.value.action.target_group_key].arn : null

    dynamic "redirect" {
      for_each = each.value.action.type == "redirect" ? [each.value.action.redirect] : []
      content {
        port        = redirect.value.port
        protocol    = redirect.value.protocol
        status_code = redirect.value.status_code
        host        = redirect.value.host
        path        = redirect.value.path
        query       = redirect.value.query
      }
    }

    dynamic "fixed_response" {
      for_each = each.value.action.type == "fixed-response" ? [each.value.action.fixed_response] : []
      content {
        content_type = fixed_response.value.content_type
        message_body = fixed_response.value.message_body
        status_code  = fixed_response.value.status_code
      }
    }
  }

  dynamic "condition" {
    for_each = each.value.conditions
    content {
      dynamic "path_pattern" {
        for_each = condition.value.type == "path-pattern" ? [condition.value] : []
        content {
          values = path_pattern.value.values
        }
      }

      dynamic "host_header" {
        for_each = condition.value.type == "host-header" ? [condition.value] : []
        content {
          values = host_header.value.values
        }
      }
    }
  }

  tags = merge(var.common_tags, {
    Name   = "${var.project_name}-${var.environment}-${each.key}-https-rule"
    Module = "alb"
  })
}