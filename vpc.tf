# Public VPC
resource "aws_vpc" "public" {

  cidr_block           = var.cidr_block_vpc_public

  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name = "vpc-pub-private"
  }
}

# Private VPC
resource "aws_vpc" "private" {

  cidr_block           = var.cidr_block_vpc_private

  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name = "vpc-private"
  }
}