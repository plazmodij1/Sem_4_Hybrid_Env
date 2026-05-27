terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.42.0"
    }
  }

  backend "s3" {
    bucket = "cicd-bucket-71huby"
    key = "env/dev/terraform.tfstate"
    region = "eu-central-1"
  }
}