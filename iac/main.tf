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
}


resource "random_id" "suffix" {
  byte_length = 4
}

# -----------------------------
# Primary S3 Bucket (artifacts)
# -----------------------------
resource "aws_s3_bucket" "artifacts" {
  bucket = "eac-demo-artifacts-${random_id.suffix.hex}"

  tags = {
    Project = "unified-eac"
    Role    = "primary"
  }
}

# -----------------------------
# Logging Bucket
# -----------------------------
resource "aws_s3_bucket" "artifacts_log" {
  bucket = "eac-artifacts-logs-${random_id.suffix.hex}"

  tags = {
    Project = "unified-eac"
    Role    = "log"
  }
}

resource "aws_s3_bucket_logging" "artifacts_logging" {
  bucket        = aws_s3_bucket.artifacts.id
  target_bucket = aws_s3_bucket.artifacts_log.id
  target_prefix = "log/"
}

# -----------------------------
# Destination Bucket (Replication)
# -----------------------------
resource "aws_s3_bucket" "destination_bucket" {
  provider = aws.replica
  bucket   = "eac-artifacts-destination-${random_id.suffix.hex}"

  versioning {
    enabled = true
  }

  tags = {
    Project = "unified-eac"
    Role    = "replica"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "destination_bucket_encryption" {
  bucket = aws_s3_bucket.destination_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      #sse_algorithm = "aws:kms"
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts_encryption" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      #sse_algorithm = "aws:kms"
      sse_algorithm = "AES256"
    }
  }
}


# -----------------------------
# IAM Role for Replication
# -----------------------------
resource "aws_iam_role" "replication_role" {
  name = "eac-replication-role-${random_id.suffix.hex}"

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

# -----------------------------
# Bucket Lifecycle Policy
# -----------------------------
resource "aws_s3_bucket_lifecycle_configuration" "artifacts_lifecycle" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-old-objects"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 30
    }
  }
}

# -----------------------------
# Replication Configuration
# -----------------------------
resource "aws_s3_bucket_replication_configuration" "artifacts_replication" {
  depends_on = [aws_iam_role_policy.replication_policy]
  bucket     = aws_s3_bucket.artifacts.id
  role       = aws_iam_role.replication_role.arn

  rule {
    id     = "replicate-to-destination"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.destination_bucket.arn
      storage_class = "STANDARD"
    }
  }
}

# -----------------------------
# Outputs
# -----------------------------
output "artifacts_bucket_name" {
  value = aws_s3_bucket.artifacts.bucket
}

output "destination_bucket_name" {
  value = aws_s3_bucket.destination_bucket.bucket
}

output "log_bucket_name" {
  value = aws_s3_bucket.artifacts_log.bucket
}
