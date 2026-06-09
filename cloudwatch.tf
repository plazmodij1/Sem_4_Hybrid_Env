# EventBridge rule looking at the new JSON files in the bucket
resource "aws_cloudwatch_event_rule" "s3_json_upload" {
  name        = "Capture-S3-JSON-Uploads"
  description = "Triggered when a new config JSON lands in the master bucket"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = { name = ["fontys-marko-config-master"] } #change to proftask s3 bucket
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

