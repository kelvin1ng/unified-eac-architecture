# -------------------------------------------------------------------
# Log Bucket + Access Logging + Replication
# -------------------------------------------------------------------

resource "aws_s3_bucket" "artifacts_log" {
  bucket = "eac-artifacts-logs-${var.random_suffix}"

  tags = {
    Project = var.project_tag
    Role    = "log"
  }
}

# Enforce KMS encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts_log_encryption" {
  bucket = aws_s3_bucket.artifacts_log.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "artifacts_log_versioning" {
  bucket = aws_s3_bucket.artifacts_log.id
  versioning_configuration {
    status = "Enabled"
  }
  /*
  depends_on = [
    aws_s3_bucket_replication_configuration.artifacts_log_replication
  ]
*/
}

# Block public access
resource "aws_s3_bucket_public_access_block" "artifacts_log_public_access" {
  bucket                  = aws_s3_bucket.artifacts_log.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Log from primary artifacts bucket → log bucket
resource "aws_s3_bucket_logging" "artifacts_access_logging" {
  bucket        = aws_s3_bucket.artifacts.id
  target_bucket = aws_s3_bucket.artifacts_log.id
  target_prefix = "artifacts/"
}

resource "aws_s3_bucket" "destination_log" {
  provider = aws.replica
  bucket   = "eac-artifacts-logs-replica-${var.random_suffix}"
  tags = {
    Project = "unified-eac"
    Role    = "replica-log"
  }
}

# --- KMS encryption ---
resource "aws_s3_bucket_server_side_encryption_configuration" "destination_log_encryption" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_log.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# --- Versioning ---
resource "aws_s3_bucket_versioning" "destination_log_versioning" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_log.id

  versioning_configuration {
    status = "Enabled"
  }
}

# --- Public Access Block ---
resource "aws_s3_bucket_public_access_block" "destination_log_pab" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_log.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Lifecycle ---
resource "aws_s3_bucket_lifecycle_configuration" "destination_log_lifecycle" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_log.id

  rule {
    id     = "expire-destination-log-objects"
    status = "Enabled"
    filter { prefix = "" }

    expiration { days = 365 }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# --- Replication (optional, same-region or cross-region) ---
resource "aws_s3_bucket_replication_configuration" "destination_log_replication" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_log.id
  role     = aws_iam_role.replication_role.arn

  depends_on = [aws_s3_bucket_versioning.destination_log_versioning]

  rule {
    id     = "replicate-destination-logs"
    status = "Enabled"
    filter { prefix = "" }

    delete_marker_replication { status = "Disabled" }

    destination {
      bucket        = aws_s3_bucket.artifacts_log.arn
      storage_class = "STANDARD_IA"
    }
  }
}

# --- Event Notifications ---
resource "aws_s3_bucket_notification" "destination_log_notifications" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_log.id

  topic {
    topic_arn = aws_sns_topic.artifacts_events_replica.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_sns_topic_policy.allow_s3_publish_replica
  ]
}

# Log from destination bucket → log bucket
resource "aws_s3_bucket_logging" "destination_access_logging" {
  provider      = aws.replica
  bucket        = aws_s3_bucket.destination_bucket.id
  target_bucket = aws_s3_bucket.destination_log.id
  target_prefix = "replica/"
}

# Lifecycle management
resource "aws_s3_bucket_lifecycle_configuration" "artifacts_log_lifecycle" {
  bucket = aws_s3_bucket.artifacts_log.id

  rule {
    id     = "abort-failed-uploads"
    status = "Enabled"
    filter { prefix = "" }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# -------------------------------------------------------------------
# Cross-region replication for log bucket
# -------------------------------------------------------------------
# This satisfies CKV_AWS_144
resource "aws_s3_bucket_replication_configuration" "artifacts_log_replication" {
  bucket = aws_s3_bucket.artifacts_log.id
  role   = aws_iam_role.replication_role.arn

  depends_on = [
    aws_s3_bucket_versioning.artifacts_log_versioning
  ]

  rule {
    id     = "replicate-artifacts-log"
    status = "Enabled"
    filter { prefix = "" }

    delete_marker_replication {
      status = "Disabled"
    }

    destination {
      bucket        = aws_s3_bucket.destination_bucket.arn
      storage_class = "STANDARD"
    }
  }
}

