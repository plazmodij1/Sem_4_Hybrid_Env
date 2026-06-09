data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file  = "./lambda.js"
  output_path = "./lambda.zip"
}

data "aws_route53_zone" "fontys_zone" {
  name = "fontys-proftask.lat"

  tags = {
    Name = "Fontys Zone"
  }
}

data "aws_s3_bucket" "main" {
  bucket = "fontys-marko-terraform-state-bucket"
}