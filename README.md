# AWS Secrets Manager Rotation Automation

[![Security Pipeline](https://github.com/Fmbravoglobal/aws-secrets-rotation-automation/actions/workflows/security-pipeline.yml/badge.svg)](https://github.com/Fmbravoglobal/aws-secrets-rotation-automation/actions)

## Overview

An automated secrets rotation system built on AWS Secrets Manager and Lambda. Implements zero-downtime rotation of database credentials, API keys, and service account tokens with validation, SNS alerting, and full audit trail.

Enforces credential hygiene best practices by automating the 4-step rotation lifecycle: createSecret → setSecret → testSecret → finishSecret.

## Architecture Components

- AWS Secrets Manager (secret storage and rotation orchestration)
- AWS Lambda (rotation function)
- AWS KMS (secrets encryption with customer-managed key)
- AWS SNS (rotation success/failure alerts)
- AWS IAM (least-privilege rotation role)
- Terraform Infrastructure as Code
- GitHub Actions CI/CD pipeline

## Rotation Workflow

1. Secrets Manager triggers Lambda rotation function
2. Lambda generates cryptographically secure new credential
3. New credential staged as AWSPENDING version
4. Validation test executed against target system
5. AWSPENDING promoted to AWSCURRENT
6. SNS notification sent on success or failure

## Security Controls

- KMS encryption for all secrets at rest
- 30-day automatic rotation schedule
- Cryptographically secure password generation (32+ chars)
- SNS alerting for rotation events
- Least-privilege IAM role for Lambda

## Author

**Oluwafemi Alabi Okunlola** | Cloud Security Engineer
[oluwafemiokunlola308@gmail.com](mailto:oluwafemiokunlola308@gmail.com)
