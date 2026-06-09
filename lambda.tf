# Lambda function for deploying user containers (ECS)
resource "aws_lambda_function" "main" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "GitOps-ECS-Orchestrator"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_functions.lambda_handler"
  runtime       = "python3.10"

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      ECS_CLUSTER_NAME = aws_ecs_cluster.main.name
      ECS_TASK_DEFINITION = aws_ecs_task_definition.apache_template.family
      APP_SUBNET_ID = aws_subnet.private["app"].id
      ECS_SECURITY_GROUP_ID = aws_security_group.ecs.id
    }
  }

  tags = {
    Name = "Lambda-instance"
  }
}

resource "aws_lambda_permission" "alb" {
  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_json_upload.arn
}