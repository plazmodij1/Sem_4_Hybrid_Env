#resource "aws_ecs_task_definition" "frontend-task" {
#  family                    = "frontend-ui-task"
#  network_mode              = "awsvpc"
#  requires_compatibilities  = ["FARGATE"]
#  cpu                       = "256"
#  memory                    = "512"
#  execution_role_arn        = aws_iam_role.ecs_task_execution.arn
#
#  container_definitions = jsonencode([
#    {
#      name      = "frontend-ui"
#      image     = "027053845110.dkr.ecr.eu-central-1.amazonaws.com/frontend-ui" # change this when the image is in the ecr
#      essential = true
#      portMappings = [
#        {
#          containerPort = 80
#          hostPort      = 80
#          protocol      = "tcp"
#        }
#      ]
#      logConfiguration = {
#        logDriver = "awslogs"
#        options = {
#          "awslogs-group"         = "/ecs/frontend-ui"
#          "awslogs-region"        = "eu-central-1"
#          "awslogs-stream-prefix" = "ecs"
#        }
#      }
#    }
#  ])
#}
#
#resource "aws_ecs_service" "frontend_service" {
#  name              = "frontend-service"
#  cluster           = aws_ecs_cluster.main.id
#  task_definition   = aws_ecs_task_definition.frontend-task.arn
#  desired_count     = 1
#  launch_type       = "FARGATE"
#
#  network_configuration {
#    subnets           = [aws_subnet.private["app"].id]
#    security_groups   = [aws_security_group.ecs.id]
#    assign_public_ip  = false
#  }
#
#  load_balancer {
#    target_group_arn  = aws_lb_target_group.frontend_tg.arn
#    container_name    = "frontend-ui"
#    container_port    = 80
#  }
#}

resource "aws_ecs_task_definition" "user_frontend" {
  family = "hybrid-user-frontend"
  requires_compatibilities  = ["FARGATE"]
  network_mode              = "awsvpc"
  cpu                       = "256"
  memory                    = "512"
  execution_role_arn        = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name = "user-panel"
    image = "027053845110.dkr.ecr.eu-central-1.amazonaws.com/hybrid-user-frontend" #change this for the proftask project
    essential = true
    portMappings = [{
      containerPort = 80
      protocol = "tcp"
  }]
  logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.user_frontend.name
        "awslogs-region"        = "eu-central-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "admin_frontend" {
  family = "hybrid-admin-frontend"
  requires_compatibilities  = ["FARGATE"]
  network_mode              = "awsvpc"
  cpu                       = "256"
  memory                    = "512"
  execution_role_arn        = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name = "admin-panel"
    image = "027053845110.dkr.ecr.eu-central-1.amazonaws.com/hybrid-admin-frontend" #change this for the proftask project
    essential = true
    portMappings = [{
      containerPort = 80
      protocol = "tcp"
  }]
  logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.user_frontend.name
        "awslogs-region"        = "eu-central-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "user_frontend" {
  name = "hybrid-user-service"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.user_frontend.arn
  desired_count = 1 # to stop the service run: aws ecs update-service --cluster hybrid-compute-cluster --service your-frontend-service-name --desired-count 0
  launch_type = "FARGATE"

  network_configuration {
    subnets = [aws_subnet.private["app"].id]
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.user_frontend.arn
    container_name = "user-panel"
    container_port = 80
  }

  depends_on = [aws_lb_listener_rule.user_routing]
}

resource "aws_ecs_service" "admin_frontend" {
  name = "hybrid-admin-service"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.admin_frontend.arn
  desired_count = 1
  launch_type = "FARGATE"

  network_configuration {
    subnets = [aws_subnet.private["app"].id]
    security_groups = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.admin_frontend.arn
    container_name = "admin-panel"
    container_port = 80
  }

  depends_on = [aws_lb_listener_rule.admin_routing]

}