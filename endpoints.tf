# ECR API endpoint (For Auth and Docker API calls)
resource "aws_vpc_endpoint" "ecr_api" {
    vpc_id = aws_vpc.private.id
    service_name = "com.amazonaws.eu-central-1.ecr.api"
    vpc_endpoint_type = "Interface"
    private_dns_enabled = true
    subnet_ids = [aws_subnet.private["data-1"].id, aws_subnet.private["app"].id]
    security_group_ids = [aws_security_group.vpc_endpoints.id]
}

# ECR DKR endpoint (for pulling image data)
resource "aws_vpc_endpoint" "ecr_dkr" {
    vpc_id = aws_vpc.private.id
    service_name = "com.amazonaws.eu-central-1.ecr.dkr"
    vpc_endpoint_type = "Interface"
    private_dns_enabled = true
    subnet_ids = [aws_subnet.private["data-1"].id, aws_subnet.private["app"].id]
    security_group_ids = [aws_security_group.vpc_endpoints.id]
}

# S3 gateway endpoint (Routes traffic to S3 locally)
resource "aws_vpc_endpoint" "s3_gateway" {
    vpc_id = aws_vpc.private.id
    service_name = "com.amazonaws.eu-central-1.s3"
    vpc_endpoint_type = "Gateway"
    route_table_ids = [aws_route_table.private.id]
}

# ELB endpoint (For modifying ALB Rules and Target Groups via Boto3)
resource "aws_vpc_endpoint" "elasticloadbalancing" {
    vpc_id              = aws_vpc.private.id
    service_name        = "com.amazonaws.eu-central-1.elasticloadbalancing"
    vpc_endpoint_type   = "Interface"
    private_dns_enabled = true
    subnet_ids          = [aws_subnet.private["data-1"].id, aws_subnet.private["app"].id]
    security_group_ids  = [aws_security_group.vpc_endpoints.id]
}


# Cloudwatch logs endpoint 
resource "aws_vpc_endpoint" "cloudwatch_logs" {
    vpc_id = aws_vpc.private.id
    service_name = "com.amazonaws.eu-central-1.logs"
    vpc_endpoint_type = "Interface"
    private_dns_enabled = true
    subnet_ids = [aws_subnet.private["data-1"].id, aws_subnet.private["app"].id]
    security_group_ids = [aws_security_group.vpc_endpoints.id]
}

# SSM endpoint
resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.private.id
  service_name      = "com.amazonaws.eu-central-1.ssm"
  vpc_endpoint_type = "Interface"
  
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  subnet_ids         = [aws_subnet.private["data-1"].id, aws_subnet.private["app"].id]

  private_dns_enabled = true 
}