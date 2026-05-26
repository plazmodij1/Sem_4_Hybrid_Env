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

# AWS WEB SERVER (Monitored)
resource "aws_instance" "web1" {
  ami                    = "ami-0a49b025fffbbdac6"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  
  monitoring = true

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

# SOA RECORD
resource "aws_route53_record" "fontys_soa" {
  zone_id = aws_route53_zone.fontys_zone.zone_id
  name    = "fontys-proftask.lat"
  type    = "SOA"
  ttl     = 900

  records = [
    "ns-368.awsdns-46.com. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400"
  ]
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

# METRICS FOR S3 (Useful for CloudWatch/Grafana)
resource "aws_s3_bucket_metric" "terraform_state_metrics" {
  bucket = aws_s3_bucket.terraform_state.id
  name   = "EntireBucket"
}

# ENABLE CLOUDTRAIL FOR CONFIGURATION MONITORING
resource "aws_cloudtrail" "infrastructure_trail" {
  name                          = "infrastructure-monitoring-trail"
  s3_bucket_name                = aws_s3_bucket.terraform_state.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket_policy.cloudtrail_policy]
}

# POLICY TO ALLOW CLOUDTRAIL TO WRITE TO S3
resource "aws_s3_bucket_policy" "cloudtrail_policy" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${aws_s3_bucket.terraform_state.id}"
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${aws_s3_bucket.terraform_state.id}/AWSLogs/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
POLICY
}

# ------------------------------------------------------------- #
# GRAFANA MONITORING SETUP (PUBLIC)
# ------------------------------------------------------------- #

# IAM ROLE FOR EC2 TO READ CLOUDWATCH
resource "aws_iam_role" "grafana_iam_role" {
  name = "grafana_cloudwatch_role_public"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Attach permissions to read metrics and CloudTrail logs from S3
resource "aws_iam_role_policy_attachment" "grafana_cw_access" {
  role       = aws_iam_role.grafana_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "grafana_s3_access" {
  role       = aws_iam_role.grafana_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "grafana_instance_profile" {
  name = "grafana_instance_profile_public"
  role = aws_iam_role.grafana_iam_role.name
}

# GRAFANA SECURITY GROUP
resource "aws_security_group" "grafana_sg" {
  name   = "grafana-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

# GRAFANA EC2 INSTANCE IN PUBLIC SUBNET
resource "aws_instance" "grafana" {
  ami                    = "ami-0a49b025fffbbdac6"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_b.id
  vpc_security_group_ids = [aws_security_group.grafana_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.grafana_instance_profile.name

  tags = {
    Name = "grafana-monitoring-public"
  }

  user_data = <<-EOF
#!/bin/bash
apt-get update -y
apt-get install -y apt-transport-https software-properties-common wget curl gnupg2

# Install Grafana
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
apt-get update -y
apt-get install -y grafana

# Pre-Provision CloudWatch Datasource
mkdir -p /etc/grafana/provisioning/datasources/
cat <<EOT > /etc/grafana/provisioning/datasources/cloudwatch.yaml
apiVersion: 1
datasources:
  - name: CloudWatch
    type: cloudwatch
    access: proxy
    uid: cloudwatch
    jsonData:
      authType: default
      defaultRegion: eu-central-1
EOT

systemctl enable grafana-server
systemctl start grafana-server
EOF
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

output "grafana_url" {
  value = "http://${aws_instance.grafana.public_ip}:3000"
}

# TERRAFORM BACKEND CONFIGURATION
terraform {
  backend "s3" {
    bucket  = "fontys-terraform-state-bucket"
    key     = "hybrid-cloud/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true
  }
}
