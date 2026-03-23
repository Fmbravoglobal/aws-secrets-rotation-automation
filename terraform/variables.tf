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
