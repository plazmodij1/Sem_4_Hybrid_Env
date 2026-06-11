data"aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "archive_file" "lambda_zip_orch" {
  type        = "zip"
  source_file  = "${path.module}/lambda_orchestrator/lambda_function.py"
  output_path = "${path.module}/lambda_orchestrator/function.zip/function.zip"
}

data "archive_file" "lambda_zip_alb" {
  type        = "zip"
  source_file  = "${path.module}/alb-dynamic-registrar/lambda_function.py"
  output_path = "${path.module}/alb-dynamic-registrar/function.zip/function.zip"
}

data "aws_route53_zone" "fontys_zone" {
  name = "fontys-proftask.lat"
  private_zone = false

  tags = {
    Name = "Fontys Zone"
  }
}

data "aws_s3_bucket" "main" {
  bucket = "fontys-marko-terraform-state-bucket"
}

# Assume role policy for the "deployments" branch in Github repo
data "aws_iam_policy_document" "github_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn] 
    }
    condition {
      test = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values = ["sts.amazonaws.com"]
    }
    condition {
      test = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = ["repo:plazmodij1/Sem_4_Hybrid_Env:ref:refs/heads/deployments"]
    }
  }
}

# Permissions required by the Python Boto3 backend
data "aws_iam_policy_document" "backend_teardown_policy" {
  
  # Compute Layer: Required to map, inspect, and kill transient Fargate containers
  statement {
    sid = "ECSTaskDiscovery"
    actions = [
      "ecs:ListTasks",
      "ecs:DescribeTasks"
    ]
    resources = ["*"] 
  }

  statement {
    sid = "ECSTaskTermination"
    actions = [
      "ecs:StopTask"
    ]
    # Scopes container killing authority strictly to tasks running in your deployment region
    resources = ["arn:aws:ecs:eu-central-1:*:task/*"] 
  }

  # Network Layer: Required to discover, dissociate, and clear load balancer ingress rules
  statement {
    sid = "ALBRuleInspection"
    actions = [
      "elasticloadbalancing:DescribeRules"
    ]
    resources = ["*"] # Describe APIs require global or full-listener boundaries to execute scans
  }

  statement {
    sid = "ALBRuleDeletion"
    actions = [
      "elasticloadbalancing:DeleteRule"
    ]
    # Matches dynamic listener rule ARN formats generated on your Application Load Balancer
    resources = ["arn:aws:elasticloadbalancing:eu-central-1:*:listener-rule/app/*/*/*/*"]
  }

  statement {
    sid = "ALBTargetGroupDeletion"
    actions = [
      "elasticloadbalancing:DeleteTargetGroup"
    ]
    # Only allows deleting sandbox groups.
    resources = ["arn:aws:elasticloadbalancing:eu-central-1:*:targetgroup/tg-*/*"]
  }
}