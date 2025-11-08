output "replication_role_arn" {
  description = "ARN of the IAM role used for S3 replication"
  value       = module.s3_secure.replication_role_arn
}

output "bucket_name" {
  description = "Name of the primary artifacts bucket"
  value       = module.s3_secure.bucket_name
}

output "bucket_arn" {
  description = "ARN of the primary artifacts bucket"
  value       = module.s3_secure.bucket_arn
}
