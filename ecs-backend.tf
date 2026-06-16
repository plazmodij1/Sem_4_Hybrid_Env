resource "aws_ecs_cluster" "main" {
    name = "hybrid-compute-cluster"
}

resource "aws_ecs_task_definition" "backend_task" {
  family                    = "fastapi-backend"
  network_mode              = "awsvpc"
  requires_compatibilities  = ["FARGATE"]
  cpu                       = "256"
  memory                    = "512"
  task_role_arn = aws_iam_role.ecs_task_role.arn
  execution_role_arn        = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name        = "fastapi-backend-container"
    image       = "318270725890.dkr.ecr.eu-central-1.amazonaws.com/fastapi-backend"
    essential   = true
    portMappings = [{
        containerPort   = 8000
        hostPort        = 8000
        protocol        = "tcp"
    }]
    environment = [
      { name = "REPO_OWNER", value = "plazmodij1" },
      { name = "REPO_NAME", value = "Sem_4_Hybrid_Env" },
      { name = "ECS_CLUSTER_NAME", value =  aws_ecs_cluster.main.name},
      { name = "ALB_LISTENER_ARN", value = aws_lb_listener.portal_listener.arn},
      { name = "DOMAIN_SUFFIX", value = "sandbox.fontys-proftask.lat"}
    ]
    secrets = [{
      name      = "GITHUB_TOKEN"
      valueFrom = "/hybrid-cloud/github-token" #CHANGE THE ACCOUNT ID
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

resource "aws_ecs_task_definition" "website-template-1" {
    family                      = "website-template-1"
    requires_compatibilities    = ["FARGATE"]
    network_mode                = "awsvpc"
    cpu                         = 256
    memory                      = 512
    task_role_arn               = aws_iam_role.ecs_task_role.arn
    execution_role_arn          = aws_iam_role.ecs_task_execution.arn

    container_definitions = jsonencode([{
        name        = "website-template-1"
        image       = "318270725890.dkr.ecr.eu-central-1.amazonaws.com/website-template-1" #change the ecr name for proftask
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
                "awslogs-group"         = "/ecs/website-template-1"
                "awslogs-region"        = "eu-central-1"
                "awslogs-stream-prefix" = "ecs"
            }
        }
    }])
}

resource "aws_ecs_task_definition" "website-template-2" {
    family                      = "website-template-2"
    requires_compatibilities    = ["FARGATE"]
    network_mode                = "awsvpc"
    cpu                         = 256
    memory                      = 512
    task_role_arn               = aws_iam_role.ecs_task_role.arn
    execution_role_arn          = aws_iam_role.ecs_task_execution.arn

    container_definitions = jsonencode([{
        name        = "website-template-2"
        image       = "318270725890.dkr.ecr.eu-central-1.amazonaws.com/website-template-2" #change the ecr name for proftask
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
                "awslogs-group"         = "/ecs/website-template-2"
                "awslogs-region"        = "eu-central-1"
                "awslogs-stream-prefix" = "ecs"
            }
        }
    }])
}