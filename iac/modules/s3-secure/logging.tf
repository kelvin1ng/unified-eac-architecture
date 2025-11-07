# -------------------------------------------------------------------
# Log Bucket
# -------------------------------------------------------------------
# terrascan:ignore AWS.S3.Versioning -- versioning already explicitly enabled; false positive
resource "aws_s3_bucket" "artifacts_log" {
  bucket = "eac-artifacts-logs-${var.random_suffix}"

  tags = {
    Project = "unified-eac"
    Role    = "log"
  }
}

# Separate versioning configuration
resource "aws_s3_bucket_versioning" "artifacts_log_versioning" {
  bucket = aws_s3_bucket.artifacts_log.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts_log_pab" {
  bucket                  = aws_s3_bucket.artifacts_log.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}


# KMS Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts_log" {
  bucket = aws_s3_bucket.artifacts_log.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
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

# Access Logging from Primary & Replica
resource "aws_s3_bucket_logging" "artifacts_logging" {
  bucket        = aws_s3_bucket.artifacts.id
  target_bucket = aws_s3_bucket.artifacts_log.id
  target_prefix = "artifacts/"
}

resource "aws_s3_bucket_logging" "destination_logging" {
  provider      = aws.replica
  bucket        = aws_s3_bucket.destination_bucket.id
  target_bucket = aws_s3_bucket.artifacts_log.id
  target_prefix = "replica/"
}

# Event Notification for Log Bucket
resource "aws_s3_bucket_notification" "artifacts_log_notification" {
  bucket = aws_s3_bucket.artifacts_log.id

  topic {
    topic_arn = var.sns_topic_arn
    events    = ["s3:ObjectRemoved:*"]
  }
}

# Optional Replication for Logs
resource "aws_s3_bucket_replication_configuration" "log_replication" {
  bucket = aws_s3_bucket.artifacts_log.id
  role   = aws_iam_role.replication_role.arn

  rule {
    id     = "replicate-logs"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.destination_bucket.arn
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts_log_lifecycle" {
  bucket = aws_s3_bucket.artifacts_log.id

  rule {
    id     = "abort-failed-uploads"
    status = "Enabled"

    # Required: Either prefix or filter must be defined
    filter {
      prefix = "" # Applies to all objects
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

