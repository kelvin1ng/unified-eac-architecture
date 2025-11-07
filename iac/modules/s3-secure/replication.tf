

resource "aws_s3_bucket_public_access_block" "destination_bucket_pab" {
  bucket                  = aws_s3_bucket.destination_bucket.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# KMS Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "destination_bucket" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# Versioning
resource "aws_s3_bucket_versioning" "destination_bucket" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Public Access Block
resource "aws_s3_bucket_public_access_block" "destination_bucket_public_access" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# Replication Config
resource "aws_s3_bucket_replication_configuration" "replication" {
  bucket = aws_s3_bucket.artifacts.id
  role   = aws_iam_role.replication_role.arn

  rule {
    id     = "replicate-all-objects"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.destination_bucket.arn
      storage_class = "STANDARD"
    }
  }
}

# Event Notification for Replica Bucket
resource "aws_s3_bucket_notification" "destination_notification" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_bucket.id

  topic {
    topic_arn = var.sns_topic_arn
    events    = ["s3:ObjectCreated:*"]
  }
}

# Replicate artifacts_log bucket to the destination bucket (cross-region)
resource "aws_s3_bucket_replication_configuration" "artifacts_log_replication" {
  role   = aws_iam_role.replication_role.arn
  bucket = aws_s3_bucket.artifacts_log.id

  rule {
    id     = "replicate-artifacts-log-to-destination"
    status = "Enabled"

    filter {
      prefix = ""
    }

    destination {
      bucket        = aws_s3_bucket.destination_bucket.arn
      storage_class = "STANDARD"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "destination_bucket_lifecycle" {
  bucket = aws_s3_bucket.destination_bucket.id

  rule {
    id     = "expire-old-objects"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Expire old objects after 30 days
    expiration {
      days = 30
    }

    # NEW: Abort incomplete multipart uploads after 7 days
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}


resource "aws_s3_bucket_replication_configuration" "replication_logs" {
  bucket = aws_s3_bucket.artifacts_log.id
  role   = aws_iam_role.replication_role.arn

  rule {
    id     = "replicate-logs"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.destination_bucket.arn
      storage_class = "STANDARD"
    }
  }
}
