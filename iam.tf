# IAM role and policy for the Lambda function
resource "aws_iam_role" "lambda" {
  name = "LambdaECSOrchestratorRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ 
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "lambda_ecs_policy" {
  name = "LambdaECSOperations"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:*:*:*" },
      { Effect = "Allow", Action = ["s3:GetObject"], Resource = "arn:aws:s3:::fontys-marko-config-master/*" }, #change to proftask s3 bucket name
      { Effect = "Allow", Action = ["ecs:RunTask", "ecs:TagResource"], Resource = "*" },
      { Effect = "Allow", Action = ["iam:PassRole"], Resource = "*" } 
    ]
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

resource "aws_iam_role" "ecs_task_execution" {
  name = "backend-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "backend_ssm_policy" {
  name        = "backend-ssm-access"
  description = "Allow backend to pull GitHub token from SSM"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:ssm:eu-central-1:027053845110:parameter/hybrid-cloud/github-token" #CHANGE THE ACCOUNT ID
      },
      {
        Action   = ["kms:Decrypt"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backend_ssm_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.backend_ssm_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Github role to access S3 bucket
resource "aws_iam_role" "github_actions_s3_role" {
  name = "GitHubActionsS3SyncRole"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json
}

resource "aws_iam_role_policy" "s3_sync_policy" {
  name = "S3MasterBucketSyncPolicy"
  role = aws_iam_role.github_actions_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = "arn:aws:s3:::fontys-marko-config-master" #change to group s3 bucket name
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::fontys-marko-config-master/*" #change to group s3 bucket name
      }
    ]
  })
}

