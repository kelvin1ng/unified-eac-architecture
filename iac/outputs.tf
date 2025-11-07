output "replication_role_arn" {
  value = aws_iam_role.replication_role.arn
}

output "bucket_name" {
  value = aws_s3_bucket.artifacts.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.artifacts.arn
}