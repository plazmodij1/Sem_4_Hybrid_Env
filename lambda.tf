# Lambda function for deploying user containers (ECS)
resource "aws_lambda_function" "main" {
  filename      = data.archive_file.lambda_zip_orch.output_path
  function_name = "GitOps-ECS-Orchestrator"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"

  source_code_hash = data.archive_file.lambda_zip_orch.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      ECS_CLUSTER_NAME = aws_ecs_cluster.main.name
      ECS_TASK_DEFINITION = aws_ecs_task_definition.website-template-1.family
      ECS_TASK_DEFINITION_2 = aws_ecs_task_definition.website-template-2.family

      APP_SUBNET_ID = aws_subnet.private["app"].id
      ECS_SECURITY_GROUP_ID = aws_security_group.ecs.id
    }
  }

  tags = {
    Name = "Lambda-instance"
  }
}

###################### Lambda ECS Orchestrator rules ######################
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

###################### Lambda ALB Dynamic Registrar rules ######################

# Lambda function for provisioning ECS tasks ALB domain
resource "aws_lambda_function" "alb_dynamic_registrar" {
  filename      = data.archive_file.lambda_zip_alb.output_path
  function_name = "ALBDynamicRegistaar"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"

  source_code_hash = data.archive_file.lambda_zip_alb.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      ALB_LISTENER_ARN = aws_lb_listener.portal_listener.arn
      VPC_ID = aws_vpc.public.id
      DOMAIN_SUFFIX = "sandbox.fontys-proftask.lat"
    }
  }

  tags = {
    Name = "Lambda-alb-instance"
  }
}

resource "aws_lambda_permission" "alb_dynamic_allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alb_dynamic_registrar.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecs_running_rule.arn
}
