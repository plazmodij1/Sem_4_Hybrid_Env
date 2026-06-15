resource "aws_route53_health_check" "alb_health" {
  fqdn              = aws_lb.main.dns_name 
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  
  failure_threshold = 2
  request_interval  = 10

  tags = {
    Name = "aws-user-panel-health"
  }
}

# Primary record pointing to AWS ALB
resource "aws_route53_record" "fontys_primary" {
  zone_id = data.aws_route53_zone.fontys_zone.zone_id
  name    = "fontys-proftask.lat"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = false
  }
  
  set_identifier = "primary"

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.alb_health.id
}

# Secondary record pointing to On-Prem server
resource "aws_route53_record" "fontys_secondary" {
  zone_id = data.aws_route53_zone.fontys_zone.zone_id
  name    = "fontys-proftask.lat"
  type    = "A"
  ttl     = 30

  records = ["145.220.75.91"]
  
  set_identifier = "secondary"

  failover_routing_policy {
    type = "SECONDARY"
  }
}

resource "aws_route53_record" "sandbox_wildcard" {
  zone_id = data.aws_route53_zone.fontys_zone.id
  name = "*.sandbox"
  type = "A"

  alias {
    name = aws_lb.main.dns_name
    zone_id = aws_lb.main.zone_id
    evaluate_target_health = false
  }
}