# -------------------------------------------------------------------
# Destination (Replica) Bucket
# -------------------------------------------------------------------
resource "aws_s3_bucket" "destination_bucket" {
  provider = aws.replica
  bucket   = "eac-artifacts-destination-${var.random_suffix}"

  tags = {
    Project = "unified-eac"
    Role    = "replica"
  }
}


# KMS Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "destination_bucket" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      #sse_algorithm = "aws:kms"
      sse_algorithm = "AES256"
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

resource "aws_iam_role" "replication_role" {
  name = "eac-replication-role-${var.random_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}


resource "aws_iam_role_policy" "replication_policy" {
  name = "replication-policy"
  role = aws_iam_role.replication_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = [aws_s3_bucket.artifacts.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl"
        ]
        Resource = ["${aws_s3_bucket.artifacts.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete"
        ]
        Resource = ["${aws_s3_bucket.destination_bucket.arn}/*"]
      }
    ]
  })
}

resource "time_sleep" "wait_for_destination_versioning" {
  depends_on = [
    aws_s3_bucket.destination_bucket,
    aws_s3_bucket_versioning.destination_bucket
  ]
  create_duration = "30s"
}

resource "aws_s3_bucket_replication_configuration" "destination_cross_region_replication" {
  bucket = aws_s3_bucket.artifacts.id
  role   = aws_iam_role.replication_role.arn

  depends_on = [
    time_sleep.wait_for_destination_versioning,
    aws_s3_bucket_versioning.artifacts_log
  ]

  rule {
    id     = "replicate-all-objects"
    status = "Enabled"

    delete_marker_replication {
      status = "Disabled"
    }

    destination {
      bucket        = aws_s3_bucket.destination_bucket.arn
      storage_class = "STANDARD"
    }
  }
}


# Note: destination_notification removed - using destination_notifications in notifications.tf instead
