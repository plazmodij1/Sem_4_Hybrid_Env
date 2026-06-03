# IAM role for the Lambda function to allow basic execution and service access
resource "aws_iam_role" "lambda" {
  name = "main-lambda-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Policy attachment to allow Lambda to access private VPC
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# The role container has while running
resource "aws_iam_role" "ecs_task_role" {
  name = "hybrid-ecs-task-role"

assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# Read only access for task role to S3 bucket 
resource "aws_iam_role_policy" "s3_read_policy" {
  name = "s3-config-read-access"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Effect   = "Allow"
      Resource = [
          data.aws_s3_bucket.main.arn,
          "${data.aws_s3_bucket.main.arn}/*"
      ]
    }]
  })
}

# The execution role (allows ECS to pull images from DockerHub and write logs)
resource "aws_iam_role" "ecs_execution_role" {
  name = "hybrid-ecs-execution-role"
  assume_role_policy = aws_iam_role.ecs_task_role.assume_role_policy
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}