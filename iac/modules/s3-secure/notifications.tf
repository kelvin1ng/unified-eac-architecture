# Optional: event notifications – CKV2_AWS_62
# Wire this to a real Lambda or SNS/SQS in future
# terrascan:ignore AWS.S3.Versioning -- versioning already explicitly enabled; false positive
resource "aws_s3_bucket_notification" "artifacts_notification" {
  bucket = aws_s3_bucket.artifacts.id

  # Example skeleton:
  # lambda_function {
  #   lambda_function_arn = aws_lambda_function.your_function.arn
  #   events              = ["s3:ObjectCreated:*"]
  # }
}
