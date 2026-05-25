provider "aws" {
  region = "eu-central-1"
}


#ROUTE53 ZONE

data "aws_route53_zone" "main" {
  name         = "canada-casestudy.nl"
  private_zone = false
}


resource "aws_route53_zone" "fontys_zone" {
  name = "fontys-proftask.lat"
}


# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}


# PUBLIC SUBNETS
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true
}


# ROUTING
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_a_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b_assoc" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}


# SECURITY GROUPS
resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web_sg" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# AWS WEB SERVER
resource "aws_instance" "web1" {
  ami                    = "ami-0a49b025fffbbdac6"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "aws-webserver"
  }

  user_data = <<EOF
#!/bin/bash
apt-get update -y
apt-get install -y apache2
echo "AWS WEB SERVER" > /var/www/html/index.html
systemctl enable apache2
systemctl start apache2
EOF
}


# APPLICATION LOAD BALANCER
resource "aws_lb" "alb" {
  name               = "hybrid-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb_sg.id]

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}


# TARGET GROUP
resource "aws_lb_target_group" "aws_tg" {
  name        = "aws-web-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    protocol = "HTTP"
    path     = "/"
    matcher  = "200"
  }
}

resource "aws_lb_target_group_attachment" "aws_attach" {
  target_group_arn = aws_lb_target_group.aws_tg.arn
  target_id        = aws_instance.web1.id
  port             = 80
}


# LISTENER
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.aws_tg.arn
  }
}


# ROUTE53 RECORD - AWS ALB
resource "aws_route53_record" "aws_app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "app.canada-casestudy.nl"
  type    = "A"

  set_identifier = "aws-alb"

  weighted_routing_policy {
    weight = 50
  }

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}


# ROUTE53 RECORD - ON PREM
resource "aws_route53_record" "onprem_app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "app.canada-casestudy.nl"
  type    = "A"
  ttl     = 60

  set_identifier = "onprem-server"

  weighted_routing_policy {
    weight = 50
  }

  records = ["145.220.75.91"]
}


# FAILOVER RECORDS FOR fontys-proftask.lat
  # PRIMARY RECORD -> AWS ALB
resource "aws_route53_record" "fontys_primary" {
  zone_id = aws_route53_zone.fontys_zone.zone_id
  name    = "fontys-proftask.lat"
  type    = "A"

  set_identifier = "primary"

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = "263c3ea1-657c-448f-a86f-b1733a256551"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

  # SECONDARY RECORD -> ON PREM SERVER
resource "aws_route53_record" "fontys_secondary" {
  zone_id = aws_route53_zone.fontys_zone.zone_id
  name    = "fontys-proftask.lat"
  type    = "A"
  ttl     = 30

  set_identifier = "secondary"

  failover_routing_policy {
    type = "SECONDARY"
  }

  records = ["145.220.75.91"]
}

# NS RECORD

resource "aws_route53_record" "fontys_ns" {
  zone_id = aws_route53_zone.fontys_zone.zone_id
  name    = "fontys-proftask.lat"
  type    = "NS"
  ttl     = 172800

  records = [
    "ns-368.awsdns-46.com.",
    "ns-1494.awsdns-58.org.",
    "ns-1993.awsdns-57.co.uk.",
    "ns-684.awsdns-21.net."
  ]
}

 #SOA RECORD

resource "aws_route53_record" "fontys_soa" {
  zone_id = aws_route53_zone.fontys_zone.zone_id
  name    = "fontys-proftask.lat"
  type    = "SOA"
  ttl     = 900

  records = [
    "ns-368.awsdns-46.com. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400"
  ]
}

# OUTPUTS

output "application_url" {
  value = "http://app.canada-casestudy.nl"
}

output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "onprem_url" {
  value = "https://145.220.75.91:3053"
}

output "fontys_domain" {
  value = "http://fontys-proftask.lat"
}




# S3 BUCKET FOR TERRAFORM STATE
resource "aws_s3_bucket" "terraform_state" {
  bucket = "fontys-terraform-state-bucket"

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


# TERRAFORM BACKEND CONFIGURATION
terraform {
  backend "s3" {
    bucket = "fontys-terraform-state-bucket"
    key    = "hybrid-cloud/terraform.tfstate"
    region = "eu-central-1"
    encrypt = true
  }
}