# -------------------------------------------------------------------
# Log Bucket
# -------------------------------------------------------------------
resource "aws_s3_bucket" "artifacts_log" {
  bucket = "eac-artifacts-logs-${var.random_suffix}"

  tags = {
    Project = "unified-eac"
    Role    = "log"
  }
}

resource "aws_s3_bucket" "destination_log" {
  provider = aws.replica
  bucket   = "eac-artifacts-logs-replica-${var.random_suffix}"

  tags = {
    Project = "unified-eac"
    Role    = "replica-log"
  }
}

# Versioning for replica log bucket
resource "aws_s3_bucket_versioning" "destination_log" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_log.id

  versioning_configuration {
    status = "Enabled"
  }
}

# KMS Encryption for artifacts_log using primary region KMS key
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts_log" {
  bucket = aws_s3_bucket.artifacts_log.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_key.arn
    }
    bucket_key_enabled = true
  }
}

# KMS key for S3 bucket encryption in replica region
data "aws_caller_identity" "current_replica_s3" {
  provider = aws.replica
}

resource "aws_kms_key" "s3_key_replica" {
  provider                = aws.replica
  description             = "KMS key for S3 bucket encryption in replica region"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current_replica_s3.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowS3Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "s3_key_replica" {
  provider      = aws.replica
  name          = "alias/s3-bucket-key-replica-${var.random_suffix}"
  target_key_id = aws_kms_key.s3_key_replica.key_id
}

# Encryption for destination_log using replica region KMS key
resource "aws_s3_bucket_server_side_encryption_configuration" "destination_log" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_log.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_key_replica.arn
    }
    bucket_key_enabled = true
  }
}

# Versioning
resource "aws_s3_bucket_versioning" "artifacts_log" {
  bucket = aws_s3_bucket.artifacts_log.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Public Access Block
resource "aws_s3_bucket_public_access_block" "artifacts_log_public_access" {
  bucket = aws_s3_bucket.artifacts_log.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Public Access Block for destination_log
resource "aws_s3_bucket_public_access_block" "destination_log_public_access" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_log.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Access Logging from Primary & Replica
resource "aws_s3_bucket_logging" "artifacts_logging" {
  bucket        = aws_s3_bucket.artifacts.id
  target_bucket = aws_s3_bucket.artifacts_log.id
  target_prefix = "artifacts/"
}

resource "aws_s3_bucket_logging" "destination_logging" {
  provider      = aws.replica
  bucket        = aws_s3_bucket.destination_bucket.id
  target_bucket = aws_s3_bucket.destination_log.id
  target_prefix = "replica/"
}

# Note: SNS topic artifacts_events should be defined in root module or passed as variable
# Removing references to undefined resource for now

# -------------------------------------------------------------------
# Delay to ensure replica versioning is active before replication
# -------------------------------------------------------------------
resource "time_sleep" "wait_for_destination_log_versioning" {
  depends_on = [aws_s3_bucket_versioning.destination_log]
  create_duration = "20s"
}

resource "aws_s3_bucket_replication_configuration" "log_replication" {
  bucket = aws_s3_bucket.artifacts_log.id
  role   = aws_iam_role.replication_role.arn

  depends_on = [
    aws_s3_bucket.destination_log,
    aws_s3_bucket_versioning.artifacts_log,
    aws_s3_bucket_versioning.destination_log,
    time_sleep.wait_for_destination_log_versioning
  ]

  rule {
    id     = "replicate-logs"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.destination_log.arn
      storage_class = "STANDARD_IA"
    }
  }
}

# Lifecycle configuration for artifacts_log
resource "aws_s3_bucket_lifecycle_configuration" "artifacts_log" {
  bucket = aws_s3_bucket.artifacts_log.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Lifecycle configuration for destination_log
resource "aws_s3_bucket_lifecycle_configuration" "destination_log" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_log.id

  rule {
    id     = "expire-old-replica-logs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# KMS key for SNS topic encryption in replica region
data "aws_caller_identity" "current_replica" {
  provider = aws.replica
}

resource "aws_kms_key" "sns_key_replica" {
  provider                = aws.replica
  description             = "KMS key for SNS topic encryption in replica region"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current_replica.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_sns_topic" "artifacts_events_replica" {
  provider          = aws.replica
  name              = "eac-artifacts-events-replica-${var.random_suffix}"
  kms_master_key_id = aws_kms_key.sns_key_replica.arn
}

resource "aws_s3_bucket_notification" "destination_log_notifications" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_log.id

  topic {
    topic_arn = aws_sns_topic.artifacts_events_replica.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_sns_topic.artifacts_events_replica,
    aws_sns_topic_policy.allow_s3_publish_destination_replica
  ]
}

