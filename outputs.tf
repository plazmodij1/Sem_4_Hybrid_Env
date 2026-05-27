output "application_url" {
  value = "http://app.canada-casestudy.nl"
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "onprem_url" {
  value = "https://145.220.75.91:3053"
}

output "fontys_domain" {
  value = "http://fontys-proftask.lat"
}

