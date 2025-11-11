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

# KMS Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts_log" {
  bucket = aws_s3_bucket.artifacts_log.id

  rule {
    apply_server_side_encryption_by_default {
      #sse_algorithm = "aws:kms"
      sse_algorithm = "AES256"
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

    delete_marker_replication {
      status = "Disabled"
    }

    destination {
      bucket        = aws_s3_bucket.destination_log.arn
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_sns_topic" "artifacts_events_replica" {
  provider = aws.replica
  name     = "eac-artifacts-events-replica-${var.random_suffix}"
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

