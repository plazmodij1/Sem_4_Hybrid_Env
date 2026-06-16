data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "archive_file" "lambda_zip_orch" {
  type        = "zip"
  source_file  = "${path.module}/lambda_orchestrator/lambda_function.py"
  output_path = "${path.module}/lambda_orchestrator/function.zip/function.zip"
}

data "archive_file" "lambda_zip_alb" {
  type        = "zip"
  source_file  = "${path.module}/alb-dynamic-registrar/lambda_function.py"
  output_path = "${path.module}/alb-dynamic-registrar/function.zip/function.zip"
}

data "aws_route53_zone" "fontys_zone" {
  name = "fontys-proftask.lat"
  private_zone = false

  tags = {
    Name = "Fontys_Zone"
  }
}

data "aws_s3_bucket" "main" {
  bucket = "fontys-terraform-state-bucket"
}

