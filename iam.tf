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
      { 
        Effect = "Allow", 
        Action = [
          "logs:CreateLogGroup", 
          "logs:CreateLogStream", 
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*" 
      },
      { 
        Effect = "Allow", 
        Action = ["s3:GetObject"], 
        Resource = "arn:aws:s3:::fontys-config-master/*" #change to proftask s3 bucket name
      }, 
      { 
        Effect = "Allow", 
        Action = [
          "ecs:RunTask", 
          "ecs:TagResource"
        ],
        Resource = "*" 
      },
      { 
        Effect = "Allow", 
        Action = ["iam:PassRole"], 
        Resource = "*" 
      } 
    ]
  })
}

resource "aws_iam_role_policy" "lambda_alb_policy" {
  name = "LambdaALBAccess"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:CreateTargetGroup",
                "elasticloadbalancing:DeleteTargetGroup",
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:DeregisterTargets",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:DeleteRule",
                "elasticloadbalancing:DescribeRules",
                "elasticloadbalancing:DescribeTargetGroups"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecs:DescribeTasks",
                "ecs:ListTasks"
            ],
            "Resource": "*"
        }
    ]
  })
}

# Policy attachment to allow Lambda to access private VPC
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
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

# Read-only access for task role to S3 bucket 
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

# Attach our custom ALB/Target Group teardown rules to the application execution space
resource "aws_iam_role_policy_attachment" "attach_teardown" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.backend_teardown.arn
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

# Standard managed policy for pulling ECR images and emitting CloudWatch streams
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allows ECS to pull the GitHub Token from SSM Parameter Store during container initialization
resource "aws_iam_role_policy_attachment" "backend_ssm_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.backend_ssm_policy.arn
}

# Allows backend to kill active ECS tasks
resource "aws_iam_policy" "backend_teardown" {
  name        = "nexus-backend-teardown-policy"
  path        = "/"
  description = "Provides the FastAPI self-service platform authority to scrub dynamic network lanes and kill active user tasks."
  policy      = data.aws_iam_policy_document.backend_teardown_policy.json
}

# Allows AWS resources to access GitHub keys
resource "aws_iam_policy" "backend_ssm_policy" {
  name        = "backend-ssm-access"
  description = "Allow backend infrastructure layers to retrieve GitHub deployment keys"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Effect   = "Allow"
        Resource = [
        "arn:aws:ssm:eu-central-1:318270725890:parameter/hybrid-cloud/github-token",
        "arn:aws:ssm:eu-central-1:318270725890:parameter/*"
        ]
      },
      {
        Action   = ["kms:Decrypt"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
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
        Resource = "arn:aws:s3:::fontys-config-master" #change to group s3 bucket name
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::fontys-config-master/*" #change to group s3 bucket name
      }
    ]
  })
}

## Cognito user pool which saves users.
resource "aws_cognito_user_pool" "website_user_pool" {
  name = "website_user_pool"
}

## Cognito users.
resource "aws_cognito_user" "admin_user" {
  username = "admin"
  user_pool_id = aws_cognito_user_pool.website_user_pool.id
  password = "Password1!" 
}

resource "aws_cognito_user" "guest_user" {
  username = "guest"
  user_pool_id = aws_cognito_user_pool.website_user_pool.id
  password = "Password1!" 
}

## Cognito user groups.
resource "aws_cognito_user_group" "admin_group" {
  name = "admin_group"  
  user_pool_id = aws_cognito_user_pool.website_user_pool.id
}

resource "aws_cognito_user_group" "guest_group" {
  name = "guest_group" 
  user_pool_id = aws_cognito_user_pool.website_user_pool.id
}

resource "aws_cognito_user_in_group" "user_in_admin_group" {
  username = aws_cognito_user.admin_user.username
  user_pool_id = aws_cognito_user_pool.website_user_pool.id
  group_name = aws_cognito_user_group.admin_group.name
}

resource "aws_cognito_user_in_group" "user_in_guest_group" {
  username = aws_cognito_user.guest_user.username
  user_pool_id = aws_cognito_user_pool.website_user_pool.id
  group_name = aws_cognito_user_group.guest_group.name
}

## Hosted Cognito login UI.
resource "aws_cognito_user_pool_domain" "cognito_domain" {
  domain = "hybrid-cloud-login-proftask"
  user_pool_id = aws_cognito_user_pool.website_user_pool.id
}

resource "aws_cognito_user_pool_client" "cognito_client" {
  name = "cognito_client"
  user_pool_id = aws_cognito_user_pool.website_user_pool.id

  allowed_oauth_flows_user_pool_client = true
  callback_urls = ["https://fontys-proftask.lat/admin/"]
  logout_urls = ["https://fontys-proftask.lat/admin/"]

  allowed_oauth_flows = ["code"]
  allowed_oauth_scopes = ["profile", "openid"]
  supported_identity_providers = ["COGNITO"]
}