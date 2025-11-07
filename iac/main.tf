#############################################
# Unified-EAC Terraform Infrastructure (Final)
# Includes: KMS, SNS, S3, Lifecycle, Notifications
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
  region = "us-east-1"
}

provider "aws" {
  alias  = "replica"
  region = "us-west-2"
}

resource "random_id" "suffix" {
  byte_length = 4
}

module "s3_secure" {
  source = "./modules/s3-secure"

  bucket_name   = "eac-artifacts-${random_id.suffix.hex}"
  project_tag   = "unified-eac"
  random_suffix = random_id.suffix.hex
  sns_topic_arn = aws_sns_topic.artifacts_events.arn # ✅ pass the SNS topic ARN

  providers = {
    aws         = aws
    aws.replica = aws.replica
  }
}





#############################################################
# Primary Artifacts Bucket
#############################################################
# terrascan:ignore AWS.S3.Versioning -- versioning already explicitly enabled; false positive
resource "aws_s3_bucket" "artifacts" {
  bucket = "eac-demo-artifacts-${random_id.suffix.hex}"

  tags = {
    Project = "unified-eac"
    Role    = "primary"
  }

}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts_encryption" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# Public Access Block
resource "aws_s3_bucket_public_access_block" "artifacts_public_access" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle for primary
resource "aws_s3_bucket_lifecycle_configuration" "artifacts_lifecycle" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-artifacts"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

#############################################################
# Log Bucket
#############################################################

resource "aws_s3_bucket" "artifacts_log" {
  bucket = "eac-artifacts-logs-${random_id.suffix.hex}"

  tags = {
    Project = "unified-eac"
    Role    = "log"
  }

  # Enable replication to the destination bucket (cross-region)
  replication_configuration {
    role = aws_iam_role.replication_role.arn

    rules {
      id     = "replicate-log-bucket"
      status = "Enabled"

      destination {
        bucket        = module.s3_secure.destination_bucket_arn
        storage_class = "STANDARD"
      }
    }
  }
}

# Separate Server-Side Encryption Configuration (new schema)
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts_log_encryption" {
  bucket = aws_s3_bucket.artifacts_log.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = null # optional: specify a KMS key ARN if you have one
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts_log_public_access" {
  bucket                  = aws_s3_bucket.artifacts_log.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts_log_lifecycle" {
  bucket = aws_s3_bucket.artifacts_log.id

  rule {
    id     = "expire-artifacts-logs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}


resource "aws_s3_bucket_public_access_block" "destination_bucket_public_access" {
  bucket                  = module.s3_secure.destination_bucket_id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "destination_lifecycle" {
  bucket = module.s3_secure.destination_bucket_id

  rule {
    id     = "expire-destination-objects"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

#############################################################
# Cross-Region Replication
#############################################################

resource "aws_iam_role" "replication_role" {
  name = "eac-replication-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "replication_policy" {
  role = aws_iam_role.replication_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Resource = [aws_s3_bucket.artifacts.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = ["${aws_s3_bucket.artifacts.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:ObjectOwnerOverrideToBucketOwner"
        ]
        Resource = ["${module.s3_secure.destination_bucket_arn}/*"]
      }
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "artifacts_replication" {
  bucket = aws_s3_bucket.artifacts.id
  role   = aws_iam_role.replication_role.arn

  rule {
    id     = "replicate-to-destination"
    status = "Enabled"

    destination {
      bucket        = module.s3_secure.destination_bucket_arn
      storage_class = "STANDARD"
    }
  }
}

#############################################################
# Access Logging + Notifications
#############################################################

resource "aws_s3_bucket_logging" "artifacts_logging" {
  bucket        = aws_s3_bucket.artifacts.id
  target_bucket = aws_s3_bucket.artifacts_log.id
  target_prefix = "log/"
}

resource "aws_s3_bucket_notification" "artifacts_notification" {
  bucket = aws_s3_bucket.artifacts.id
  topic {
    topic_arn = aws_sns_topic.artifacts_events.arn
    events    = ["s3:ObjectCreated:*"]
  }
}

# Notifications for other buckets (Compliance Fix)
resource "aws_s3_bucket_notification" "artifacts_log_notification" {
  bucket = aws_s3_bucket.artifacts_log.id
  topic {
    topic_arn = aws_sns_topic.artifacts_events.arn
    events    = ["s3:ObjectCreated:*"]
  }
}

resource "aws_s3_bucket_notification" "destination_bucket_notification" {
  bucket = module.s3_secure.destination_bucket_id
  topic {
    topic_arn = aws_sns_topic.artifacts_events.arn
    events    = ["s3:ObjectCreated:*"]
  }
}

#############################################################
# SNS Topic + KMS Encryption (No Wildcard Principal)
#############################################################

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


data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "artifacts_events" {
  name              = "eac-artifacts-events-${random_id.suffix.hex}"
  kms_master_key_id = aws_kms_key.sns_key.arn
}

# Existing topic (keep what you already have; shown for context)
# resource "aws_sns_topic" "artifacts_events" { ... }

resource "aws_s3_bucket_notification" "artifacts_notifications" {
  bucket = aws_s3_bucket.artifacts.id

  topic {
    topic_arn = aws_sns_topic.artifacts_events.arn
    events    = ["s3:ObjectCreated:*"]
  }
}

resource "aws_s3_bucket_notification" "artifacts_log_notifications" {
  bucket = aws_s3_bucket.artifacts_log.id

  topic {
    topic_arn = aws_sns_topic.artifacts_events.arn
    events    = ["s3:ObjectCreated:*"]
  }
}

resource "aws_s3_bucket_notification" "destination_notifications" {
  bucket = module.s3_secure.destination_bucket_id

  topic {
    topic_arn = aws_sns_topic.artifacts_events.arn
    events    = ["s3:ObjectCreated:*"]
  }
}

resource "aws_s3_bucket_versioning" "artifacts_versioning" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "artifacts_log_versioning" {
  bucket = aws_s3_bucket.artifacts_log.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_versioning" "destination_bucket_versioning" {
  bucket = module.s3_secure.destination_bucket_id
  versioning_configuration { status = "Enabled" }
}

