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
}

# Target Group for the Frontend (Port 80)
resource "aws_lb_target_group" "user_frontend" {
  name        = "hybrid-user-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.public.id
  target_type = "ip"

  health_check {
    path    = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

resource "aws_lb_target_group" "admin_frontend" {
  name        = "hybrid-admin-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.public.id 
  target_type = "ip"

  health_check {
    # Nginx expects the health check to include the /admin path
    path                = "/admin"
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

# Target Group for the Backend (Port 8000)
resource "aws_lb_target_group" "backend_tg" {
  name        = "backend-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.public.id
  target_type = "ip" 
  
  health_check {
    path    = "/docs"
    matcher = "200"
  }
}

resource "aws_lb_target_group_attachment" "aws_attach" {
  target_group_arn  = aws_lb_target_group.lambda.arn
  target_id         = aws_lambda_function.main.arn
  depends_on        = [aws_lambda_permission.alb]
}

# Listener for the portal
resource "aws_lb_listener" "portal_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

    default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: Route Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "admin_routing" {
  listener_arn = aws_lb_listener.portal_listener.arn
  priority     = 50

  action {
    type              = "forward"
    target_group_arn  = aws_lb_target_group.admin_frontend.arn
  }

  condition {
    path_pattern {
      values = ["/*"] 
      #values = ["/admin*"] 
    }
  }
}

resource "aws_lb_listener_rule" "user_routing" {
  listener_arn = aws_lb_listener.portal_listener.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.user_frontend.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}



# Listener Rule for the API
resource "aws_lb_listener_rule" "api_routing" {
  listener_arn = aws_lb_listener.portal_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}