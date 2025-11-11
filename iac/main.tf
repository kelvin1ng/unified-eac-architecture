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
      time = {
      source  = "hashicorp/time"
      version = "~> 0.9.0"
    }
  }

  required_version = ">= 1.5.0"
}

provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "replica"
  region = "us-west-2"
}

module "s3_secure" {
  source = "./modules/s3-secure"

  bucket_name   = "eac-demo-artifacts-${random_id.suffix.hex}"
  project_tag   = "unified-eac"
  random_suffix = random_id.suffix.hex

  providers = {
    aws         = aws
    aws.replica = aws.replica
  }
}


resource "random_id" "suffix" {
  byte_length = 4
}

# Primary and log buckets are now managed by the s3_secure module
# Using module outputs for references

# -----------------------------
# Destination Bucket (Replication)
# -----------------------------
# Destination bucket is now managed by the s3_secure module
# Removing duplicate definition to avoid conflicts

# Encryption is now managed by the s3_secure module


# IAM Role for Replication is now managed by the s3_secure module
# Removing duplicate definition to avoid conflicts

# Lifecycle policy is now managed by the s3_secure module

# -----------------------------
# Replication Configuration
# -----------------------------
# Replication is now managed by the s3_secure module
# Removing duplicate definition to avoid conflicts

# -----------------------------
# Outputs
# -----------------------------
output "artifacts_bucket_name" {
  value = module.s3_secure.bucket_name
}

output "destination_bucket_name" {
  value = module.s3_secure.destination_bucket_id
}

output "log_bucket_name" {
  value = "eac-artifacts-logs-${random_id.suffix.hex}"
}
