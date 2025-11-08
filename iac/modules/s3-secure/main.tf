#############################################
# S3 Secure Module – Core Buckets
# - Primary Artifacts Bucket (primary region)
# - Destination Bucket (replica region)
# - Default Encryption, Versioning, Lifecycle,
#   Public Access Block
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

# Default KMS encryption for primary bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts_encryption" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# Public Access Block for primary bucket
resource "aws_s3_bucket_public_access_block" "artifacts_public_access" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration for primary bucket
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

# Versioning for primary bucket
resource "aws_s3_bucket_versioning" "artifacts_versioning" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
  /*
  depends_on = [
    aws_s3_bucket_replication_configuration.artifacts_replication
  ]
*/
}

#############################################
# Destination Bucket (Replica Region)
#############################################

resource "aws_s3_bucket" "destination_bucket" {
  provider = aws.replica
  bucket   = "eac-artifacts-destination-${var.random_suffix}"

  tags = {
    Project = var.project_tag
    Role    = "destination"
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

resource "aws_s3_bucket_versioning" "destination_versioning" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
  /*
  depends_on = [
    aws_s3_bucket_replication_configuration.destination_cross_region_replication
  ]
*/
}
