#############################################
# Cross-Region Replication
#############################################

# IAM Role for replication
resource "aws_iam_role" "replication_role" {
  name = "eac-replication-role-${var.random_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# IAM Policy for replication access
resource "aws_iam_role_policy" "replication_policy" {
  name = "eac-replication-policy-${var.random_suffix}"
  role = aws_iam_role.replication_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          aws_s3_bucket.artifacts_log.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = [
          "${aws_s3_bucket.artifacts.arn}/*",
          "${aws_s3_bucket.artifacts_log.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:ObjectOwnerOverrideToBucketOwner"
        ]
        Resource = [
          "${aws_s3_bucket.destination_bucket.arn}/*"
        ]
      }
    ]
  })
}

#############################################
# Primary Artifacts → Destination
#############################################
resource "aws_s3_bucket_replication_configuration" "artifacts_replication" {
  bucket = aws_s3_bucket.artifacts.id
  role   = aws_iam_role.replication_role.arn

  depends_on = [
    aws_s3_bucket_versioning.artifacts_versioning,
    aws_s3_bucket_versioning.destination_versioning
  ]

  rule {
    id     = "replicate-artifacts-to-destination"
    status = "Enabled"
    filter { prefix = "" }

    # 🟩 Required for new S3 replication schema
    delete_marker_replication {
      status = "Disabled"
    }
    
    destination {
      bucket        = aws_s3_bucket.destination_bucket.arn
      storage_class = "STANDARD"
    }
  }
}


#############################################
# Destination → Cross-Region Redundancy
#############################################
# To satisfy CKV_AWS_144 for the destination bucket,
# we replicate it back to the primary region as a DR copy.
resource "aws_s3_bucket_replication_configuration" "destination_cross_region_replication" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_bucket.id
  role     = aws_iam_role.replication_role.arn

  depends_on = [
    aws_s3_bucket_versioning.destination_versioning
  ]

  rule {
    id     = "replicate-destination-cross-region"
    status = "Enabled"
    filter { prefix = "" }

    # NEW: required by AWS API (as of 2023+)
    delete_marker_replication {
      status = "Disabled"
    }

    destination {
      bucket        = aws_s3_bucket.artifacts.arn
      storage_class = "STANDARD_IA"
    }
  }
}

