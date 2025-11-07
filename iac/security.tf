#############################################
# S3 Security Controls – Public Access Blocks
# Satisfies: CKV2_AWS_6
#############################################

# Public Access Block for primary artifacts bucket
resource "aws_s3_bucket_public_access_block" "artifacts_pab" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket.artifacts]
}

# Public Access Block for log bucket
resource "aws_s3_bucket_public_access_block" "artifacts_log_pab" {
  bucket                  = aws_s3_bucket.artifacts_log.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket.artifacts_log]
}

resource "aws_s3_bucket_public_access_block" "destination_bucket_pab" {
  bucket                  = module.s3_secure.destination_bucket_id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [module.s3_secure]
}

