variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "secrot"
}
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}
variable "lambda_s3_bucket" {
  description = "S3 bucket containing the Lambda deployment package"
  type        = string
  default     = "my-lambda-deployments"
}
variable "lambda_s3_key" {
  description = "S3 key for the Lambda deployment package"
  type        = string
  default     = "rotation_lambda.zip"
}
