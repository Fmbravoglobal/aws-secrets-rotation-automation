terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}
provider "aws" { region = var.aws_region }

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "secrets_key" {
  description             = "KMS key for Secrets Manager encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  tags = { Project = "aws-secrets-rotation-automation" }
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name       = "${var.prefix}-db-credentials"
  kms_key_id = aws_kms_key.secrets_key.arn
  recovery_window_in_days = 7
  tags = { Project = "aws-secrets-rotation-automation" }
}

resource "aws_secretsmanager_secret_rotation" "db_rotation" {
  secret_id           = aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = aws_lambda_function.rotation_lambda.arn
  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_lambda_function" "rotation_lambda" {
  filename      = "rotation_lambda.zip"
  function_name = "${var.prefix}-secrets-rotation"
  role          = aws_iam_role.rotation_role.arn
  handler       = "app.main.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
  kms_key_arn   = aws_kms_key.secrets_key.arn
  environment {
    variables = {
      SNS_TOPIC_ARN    = aws_sns_topic.rotation_alerts.arn
      ROTATION_ENABLED = "true"
    }
  }
  tags = { Project = "aws-secrets-rotation-automation" }
}

resource "aws_sns_topic" "rotation_alerts" {
  name              = "${var.prefix}-rotation-alerts"
  kms_master_key_id = aws_kms_key.secrets_key.arn
  tags = { Project = "aws-secrets-rotation-automation" }
}

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
}
