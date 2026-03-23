output "secret_arn" {
  value = aws_secretsmanager_secret.db_credentials.arn
}
output "lambda_function_name" {
  value = aws_lambda_function.rotation_lambda.function_name
}
output "sns_topic_arn" {
  value = aws_sns_topic.rotation_alerts.arn
}
