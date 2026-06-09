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