
##################################################################################################################################
########################################## THIS FILE IS ONLY FOR FIRST TIME DEPLOYMENT. ########################################## 
##################################################################################################################################

provider "aws" {
  region = "eu-central-1"
}

# S3 BUCKET FOR TERRAFORM STATE
resource "aws_s3_bucket" "terraform_state" {
  bucket = "fontys-marko-terraform-state-bucket"

  tags = {
    Name        = "Terraform State Bucket"
    Environment = "Production"
  }
}

# ENABLE VERSIONING
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# SERVER SIDE ENCRYPTION
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# BLOCK PUBLIC ACCESS
resource "aws_s3_bucket_public_access_block" "terraform_state_public_block" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Adding DynamoDB resource to create lock file when running 'terraform apply'
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "lock-table-dynamodb" 
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock Table"
  }
}

resource "aws_route53_zone" "fontys_zone" {
  name = "fontys-proftask.lat"
}

resource "aws_ecr_repository" "httpd_repo" {
  name                 = "httpd-repo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # Makes it easier to clean up later
}