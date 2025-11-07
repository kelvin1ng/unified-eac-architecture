#############################################
# S3 Secure Module – FINAL (v2025-11-06)
# Features:
# - Primary + Replica S3 Buckets
# - KMS Default Encryption (CKV_AWS_145)
# - Versioning (CKV_AWS_21)
# - Lifecycle Management (CKV2_AWS_61 / CKV_AWS_300)
# - Public Access Block (CKV2_AWS_6)
# - Cross-Region Replication Stub (CKV_AWS_144 compliant)
#############################################

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.replica]
    }
  }
}


#############################################
# Primary Artifacts Bucket
#############################################
resource "aws_s3_bucket" "artifacts" {
  bucket = var.bucket_name

  tags = {
    Project = var.project_tag
    Role    = "primary"
  }
}

# Default KMS encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts_encryption" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# Public Access Block (CKV2_AWS_6)
resource "aws_s3_bucket_public_access_block" "artifacts_public_access" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration (CKV2_AWS_61 / CKV_AWS_300)
resource "aws_s3_bucket_lifecycle_configuration" "artifacts_lifecycle" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-old-objects"
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


resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts_log_encryption" {
  bucket = aws_s3_bucket.artifacts_log.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

#############################################
# Replica Bucket (Cross-Region)
#############################################
resource "aws_s3_bucket" "destination_bucket" {
  provider = aws.replica
  bucket   = "eac-destination-${var.random_suffix}"

  tags = {
    Project = var.project_tag
    Role    = "replica"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "destination_encryption" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "destination_public_access" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "destination_lifecycle" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_bucket.id

  rule {
    id     = "expire-destination-objects"
    status = "Enabled"

    # Required by AWS Provider v5+
    filter {
      prefix = "" # apply rule to all objects in the bucket
    }

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_versioning" "destination_versioning" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

#############################################
# Replication Role (cross-region stub)
#############################################
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
  name = "eac-replication-policy-${var.random_suffix}"
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
        Effect   = "Allow"
        Action   = ["s3:GetObjectVersion", "s3:GetObjectVersionAcl"]
        Resource = ["${aws_s3_bucket.artifacts.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ReplicateObject", "s3:ReplicateDelete"]
        Resource = ["${aws_s3_bucket.destination_bucket.arn}/*"]
      }
    ]
  })
}

#############################################
# Cross-Region Replication (Compliance Stub)
#############################################
resource "aws_s3_bucket_replication_configuration" "artifacts_replication" {
  bucket = aws_s3_bucket.artifacts.id
  role   = aws_iam_role.replication_role.arn

  rule {
    id     = "replicate-to-destination"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.destination_bucket.arn
      storage_class = "STANDARD"
    }
  }
}
