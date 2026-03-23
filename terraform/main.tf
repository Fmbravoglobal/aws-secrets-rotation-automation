terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

############################################
# KMS KEY
############################################
resource "aws_kms_key" "secrets_key" {
  description             = "KMS key for Secrets Manager encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowSecretsManager"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Project     = "aws-secrets-rotation-automation"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "secrets_key_alias" {
  name          = "alias/${var.prefix}-secrets-key"
  target_key_id = aws_kms_key.secrets_key.key_id
}

############################################
# SECRETS MANAGER
############################################
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.prefix}-db-credentials"
  kms_key_id              = aws_kms_key.secrets_key.arn
  recovery_window_in_days = 7

  tags = {
    Project     = "aws-secrets-rotation-automation"
    Environment = var.environment
  }
}

############################################
# SNS TOPIC
############################################
resource "aws_sns_topic" "rotation_alerts" {
  name              = "${var.prefix}-rotation-alerts"
  kms_master_key_id = aws_kms_key.secrets_key.arn

  tags = {
    Project     = "aws-secrets-rotation-automation"
    Environment = var.environment
  }
}

############################################
# DEAD LETTER QUEUE FOR LAMBDA
############################################
resource "aws_sqs_queue" "lambda_dlq" {
  name              = "${var.prefix}-rotation-dlq"
  kms_master_key_id = aws_kms_key.secrets_key.arn

  tags = {
    Project     = "aws-secrets-rotation-automation"
    Environment = var.environment
  }
}

############################################
# IAM ROLE FOR LAMBDA
############################################
resource "aws_iam_role" "rotation_role" {
  name = "${var.prefix}-rotation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Project     = "aws-secrets-rotation-automation"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "rotation_policy" {
  name = "${var.prefix}-rotation-policy"
  role = aws_iam_role.rotation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.secrets_key.arn
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.rotation_alerts.arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid      = "SQSDLQAccess"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.lambda_dlq.arn
      }
    ]
  })
}

############################################
# LAMBDA FUNCTION
# checkov:skip=CKV_AWS_117:VPC not required for Secrets Manager rotation demo
# checkov:skip=CKV_AWS_272:Code signing not required for demo environment
############################################
resource "aws_lambda_function" "rotation_lambda" {
  s3_bucket     = var.lambda_s3_bucket
  s3_key        = var.lambda_s3_key
  function_name = "${var.prefix}-secrets-rotation"
  role          = aws_iam_role.rotation_role.arn
  handler       = "app.main.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
  kms_key_arn   = aws_kms_key.secrets_key.arn

  reserved_concurrent_executions = 10

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      SNS_TOPIC_ARN    = aws_sns_topic.rotation_alerts.arn
      ROTATION_ENABLED = "true"
    }
  }

  tags = {
    Project     = "aws-secrets-rotation-automation"
    Environment = var.environment
  }
}

############################################
# SECRETS MANAGER ROTATION
############################################
resource "aws_secretsmanager_secret_rotation" "db_rotation" {
  secret_id           = aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = aws_lambda_function.rotation_lambda.arn

  rotation_rules {
    automatically_after_days = 30
  }
}
