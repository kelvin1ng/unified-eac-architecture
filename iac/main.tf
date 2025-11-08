#############################################
# Unified-EAC Terraform Infrastructure (Final)
# Root module: providers, randomness, SNS + KMS,
# and invocation of the s3-secure module.
#############################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "replica"
  region = "us-west-2"
}

# Used for unique bucket names
resource "random_id" "suffix" {
  byte_length = 4
}

# Caller identity used in KMS key policy
data "aws_caller_identity" "current" {}

#############################################
# KMS Key for SNS encryption
#############################################

resource "aws_kms_key" "sns_key" {
  description             = "KMS key for SNS topic encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  # No wildcard principal – allow only this account's root
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

#############################################
# SNS Topic for S3 Events
#############################################

resource "aws_sns_topic" "artifacts_events" {
  name              = "eac-artifacts-events-${random_id.suffix.hex}"
  kms_master_key_id = aws_kms_key.sns_key.arn
}

resource "aws_sns_topic_policy" "allow_s3_publish" {
  arn = aws_sns_topic.artifacts_events.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3Publish"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.artifacts_events.arn
      }
    ]
  })
}

#############################################
# S3 Secure Module (Primary + Log + Destination)
#############################################

module "s3_secure" {
  source = "./modules/s3-secure"

  bucket_name   = "eac-artifacts-${random_id.suffix.hex}"
  project_tag   = "unified-eac"
  random_suffix = random_id.suffix.hex
  sns_topic_arn = aws_sns_topic.artifacts_events.arn

  providers = {
    aws         = aws
    aws.replica = aws.replica
  }

  # Ensure SNS topic and policy exist before S3 notifications in the module
  depends_on = [
    aws_sns_topic_policy.allow_s3_publish
  ]
}
