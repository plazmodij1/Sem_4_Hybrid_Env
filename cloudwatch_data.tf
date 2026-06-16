resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "alb-high-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "ALB is returning too many 5xx responses"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  alarm_name          = "alb-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 2
  alarm_description   = "ALB response time is too high"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "lambda-errors-main"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Lambda function has errors"

  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "lambda-duration-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Average"
  threshold           = 5000
  alarm_description   = "Lambda average duration too high in ms"

  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "lambda-throttles-main"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Lambda throttling detected"

  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }
}

# EventBridge rule looking at the new JSON files in the bucket
resource "aws_cloudwatch_event_rule" "s3_json_upload" {
  name        = "Capture-S3-JSON-Uploads"
  description = "Triggered when a new config JSON lands in the master bucket"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = { name = ["fontys-config-master"] }
      object = { key = [{ suffix = ".json" }] }
    }
  })
}

# Connecting EventBridge to Lambda
resource "aws_cloudwatch_event_target" "trigger_lambda" {
  rule      = aws_cloudwatch_event_rule.s3_json_upload.name
  target_id = "TriggerGitOpsLambda"
  arn       = aws_lambda_function.main.arn
}

resource "aws_cloudwatch_event_rule" "ecs_running_rule" {
  name        = "ecs-task-running-registrar"
  description = "Triggers Lambda when an ECS task hits RUNNING state"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Task State Change"]
    detail = {
      lastStatus = ["RUNNING"]
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.ecs_running_rule.name
  target_id = "SendToRegistrarLambda"
  arn       = aws_lambda_function.alb_dynamic_registrar.arn
}

resource "aws_cloudwatch_log_group" "website-template-1" {
  name              = "/ecs/website-template-1"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "website-template-2" {
  name              = "/ecs/website-template-2"
  retention_in_days = 7
}


resource "aws_cloudwatch_log_group" "backend_logs" {
  name              = "/ecs/fastapi-backend"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "user_frontend" {
  name              = "/ecs/hybrid-user-frontend"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "admin_frontend" {
  name              = "/ecs/hybrid-admin-frontend"
  retention_in_days = 7
}
