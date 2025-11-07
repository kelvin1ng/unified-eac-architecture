output "destination_bucket_id" {
  value = aws_s3_bucket.destination_bucket.id
}

output "destination_bucket_arn" {
  value = aws_s3_bucket.destination_bucket.arn
}
