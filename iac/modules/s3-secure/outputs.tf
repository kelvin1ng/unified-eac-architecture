output "bucket_name" {
  description = "Name of the primary artifacts bucket"
  value       = aws_s3_bucket.artifacts.id
}

output "bucket_arn" {
  description = "ARN of the primary artifacts bucket"
  value       = aws_s3_bucket.artifacts.arn
}

output "destination_bucket_id" {
  description = "ID of the destination bucket"
  value       = aws_s3_bucket.destination_bucket.id
}

output "destination_bucket_arn" {
  description = "ARN of the destination bucket"
  value       = aws_s3_bucket.destination_bucket.arn
}

output "replication_role_arn" {
  description = "ARN of the IAM role used for replication"
  value       = aws_iam_role.replication_role.arn
}

