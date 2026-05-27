provider "aws" {
  region = "eu-central-1"
}

# TERRAFORM BACKEND CONFIGURATION
terraform {
  backend "s3" {
    bucket = "fontys-terraform-state-bucket"
    key    = "hybrid-cloud/terraform.tfstate"
    region = "eu-central-1"
    encrypt = true

    dynamodb_table = "lock-table-dynamodb"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}