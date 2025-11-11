resource "aws_s3_bucket" "artifacts" {
  bucket = var.bucket_name

  tags = {
    Project = var.project_tag
  }

  # Versioning for primary bucket – helps CKV_AWS_21
  versioning {
    enabled = true
  }

}

# Public access block for primary bucket – CKV2_AWS_6
resource "aws_s3_bucket_public_access_block" "artifacts_public_access" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
