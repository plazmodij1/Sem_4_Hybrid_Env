# APPLICATION LOAD BALANCER
resource "aws_lb" "main" {
  name                        = "main-alb"
  internal                    = false
  load_balancer_type          = "application"

  security_groups             = [aws_security_group.alb_sg.id]
  subnets                     = [aws_subnet.public["dmz-1"].id, aws_subnet.public["dmz-2"].id]

  enable_deletion_protection  = false

  tags = {
    Name = "main-alb"
  }
}

# TARGET GROUP
resource "aws_lb_target_group" "lambda" {
  name          = "web-server-tg"
  target_type   = "lambda"

  #health_check {
  #  enabled             = true
  #  path                = "/" # Include /health when lambda is fully deployed (Marko)
  #  interval            = 10
  #  timeout             = 5
  #  healthy_threshold   = 2
  #  unhealthy_threshold = 2
  #  matcher             = "200"
  #}
}

resource "aws_lb_target_group_attachment" "aws_attach" {
  target_group_arn  = aws_lb_target_group.lambda.arn
  target_id         = aws_lambda_function.main.arn
  depends_on        = [aws_lambda_permission.alb]
}

## LISTENER
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda.arn
  }
}