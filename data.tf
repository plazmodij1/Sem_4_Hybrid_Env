data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file  = "./lambda.js"
  output_path = "./lambda.zip"
}

data "aws_route53_zone" "fontys_zone" {
  name = "fontys-proftask.lat"
}