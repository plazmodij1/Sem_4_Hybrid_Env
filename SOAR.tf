#SNS
resource "aws_sns_topic" "alerts" {
  name = "infrastructure-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "justin.dirks@outlook.com"
}


#CLOUDWATCH AWS ENDPOINT ALARM
resource "aws_cloudwatch_metric_alarm" "aws_endpoint_down" {
  alarm_name          = "AWS-Endpoint-Down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1

  dimensions = {
    HealthCheckId = aws_route53_health_check.alb_health.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  alarm_description = "AWS ALB/Lambda endpoint is unhealthy"
}


#HHealth check for ON PREMIS ENDPOINT

resource "aws_route53_health_check" "onprem_health" {
  ip_address         = "145.220.75.91"
  port               = 3053
  type               = "HTTPS"
  resource_path      = "/health"

  failure_threshold  = 1
  request_interval   = 10

  tags = {
    Name = "onprem-health-check"
  }
}


#ALARM FOR ON PREM ENDPOINT
resource "aws_cloudwatch_metric_alarm" "onprem_endpoint_down" {
  alarm_name          = "OnPrem-Endpoint-Down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1

  dimensions = {
    HealthCheckId = aws_route53_health_check.onprem_health.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  alarm_description = "On-prem endpoint is unhealthy"
}
