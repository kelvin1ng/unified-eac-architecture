output "replication_role_arn" {
  description = "ARN of the IAM role used for S3 replication"
  value       = aws_iam_role.replication_role.arn
}

output "bucket_name" {
  description = "Name of the primary artifacts bucket"
  value       = aws_s3_bucket.artifacts.bucket
}

output "bucket_arn" {
  description = "ARN of the primary artifacts bucket"
  value       = aws_s3_bucket.artifacts.arn
}

output "log_bucket_name" {
  description = "Name of the log bucket"
  value       = aws_s3_bucket.artifacts_log.bucket
}

output "log_bucket_arn" {
  description = "ARN of the log bucket"
  value       = aws_s3_bucket.artifacts_log.arn
}

output "destination_bucket_id" {
  description = "ID of the destination replica bucket"
  value       = aws_s3_bucket.destination_bucket.id
}

output "destination_bucket_arn" {
  description = "ARN of the destination replica bucket"
  value       = aws_s3_bucket.destination_bucket.arn
}
