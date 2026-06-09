resource "aws_ecs_cluster" "main" {
    name = "hybrid-compute-cluster"
}

resource "aws_ecs_task_definition" "frontend-task" {
  family                    = "frontend-ui-task"
  network_mode              = "awsvpc"
  requires_compatibilities  = ["FARGATE"]
  cpu                       = "256"
  memory                    = "512"
  execution_role_arn        = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "frontend-ui"
      image     = "027053845110.dkr.ecr.eu-central-1.amazonaws.com/frontend-ui" # change this when the image is in the ecr
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/frontend-ui"
          "awslogs-region"        = "eu-central-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "frontend_service" {
  name              = "frontend-service"
  cluster           = aws_ecs_cluster.main.id
  task_definition   = aws_ecs_task_definition.frontend-task.arn
  desired_count     = 1
  launch_type       = "FARGATE"

  network_configuration {
    subnets           = [aws_subnet.private["app"].id]
    security_groups   = [aws_security_group.ecs.id]
    assign_public_ip  = false
  }

  load_balancer {
    target_group_arn  = aws_lb_target_group.frontend_tg.arn
    container_name    = "frontend-ui"
    container_port    = 80
  }
}

resource "aws_cloudwatch_log_group" "frontend_logs" {
  name              = "/ecs/frontend-ui"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "backend_task" {
  family                    = "fastapi-backend"
  network_mode              = "awsvpc"
  requires_compatibilities  = ["FARGATE"]
  cpu                       = "256"
  memory                    = "512"
  execution_role_arn        = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name        = "fastapi-backend-container"
    image       = "027053845110.dkr.ecr.eu-central-1.amazonaws.com/fastapi-backend"
    essential   = true
    portMappings = [{
        containerPort   = 8000
        hostPort        = 8000
        protocol        = "tcp"
    }]
    environment = [
      { name = "PFSENSE_IP", value = "145.220.75.91" },
      { name = "TRAEFIK_PORT", value = "3055" },
      { name = "REPO_OWNER", value = "plazmodij1" },
      { name = "REPO_NAME", value = "Sem_4_Hybrid_Env" },
      { name = "FRONTEND_CORS_ORIGIN", value =  ""}
    ]
    secrets = [{
      name      = "GITHUB_TOKEN"
      valueFrom = "arn:aws:ssm:eu-central-1:027053845110:parameter/hybrid-cloud/github-token" #CHANGE THE ACCOUNT ID
    }]
    logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/fastapi-backend"
          "awslogs-region"        = "eu-central-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
  }])
}

resource "aws_ecs_service" "backend_service" {
    name              = "backend-service"
    cluster           = aws_ecs_cluster.main.id
    task_definition   = aws_ecs_task_definition.backend_task.arn
    desired_count     = 1
    launch_type       = "FARGATE"

    network_configuration {
      subnets           = [aws_subnet.private["app"].id]
      security_groups   = [aws_security_group.ecs.id]
      assign_public_ip  = false
    }

    load_balancer {
      target_group_arn  = aws_lb_target_group.backend_tg.arn
      container_name    = "fastapi-backend-container"
      container_port    = 8000
    }
}

resource "aws_cloudwatch_log_group" "backend_logs" {
  name              = "/ecs/fastapi-backend"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "apache_template" {
    family                      = "apache-web-template"
    requires_compatibilities    = ["FARGATE"]
    network_mode                = "awsvpc"
    cpu                         = 256
    memory                      = 512
    task_role_arn               = aws_iam_role.ecs_task_role.arn
    execution_role_arn          = aws_iam_role.ecs_execution_role.arn

    container_definitions = jsonencode([{
        name        = "apache-container"
        image       = "027053845110.dkr.ecr.eu-central-1.amazonaws.com/httpd-repo"
        essential   = true

        portMappings = [{
            containerPort   = 80
            hostPort        = 80
            protocol        = "tcp"
        }]
        
        # Github actions will inject the S3 URL upon runtime
        environment = [
            {name = "CONFIG_URL", value = ""}
        ]

        logConfiguration = {
            logDriver = "awslogs"
            options = {
                "awslogs-group"         = "/ecs/apache-web"
                "awslogs-region"        = "eu-central-1"
                "awslogs-stream-prefix" = "ecs"
            }
        }
    }])
}



# Log group which was defined in "apache_template"
resource "aws_cloudwatch_log_group" "apache_logs" {
  name              = "/ecs/apache-web"
  retention_in_days = 7
}
