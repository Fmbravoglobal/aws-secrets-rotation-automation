output "secret_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "lambda_function_name" {
  description = "Name of the rotation Lambda function"
  value       = aws_lambda_function.rotation_lambda.function_name
}

output "sns_topic_arn" {
  description = "ARN of the SNS rotation alerts topic"
  value       = aws_sns_topic.rotation_alerts.arn
}

output "dlq_arn" {
  description = "ARN of the Lambda Dead Letter Queue"
  value       = aws_sqs_queue.lambda_dlq.arn
}
