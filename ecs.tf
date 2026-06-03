resource "aws_ecs_cluster" "hybrid_cluster" {
    name = "hybrid-compute-cluster"
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