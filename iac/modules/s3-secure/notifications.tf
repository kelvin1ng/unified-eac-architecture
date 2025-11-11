# Note: Event notifications for artifacts and artifacts_log buckets
# These would require SNS topics in the primary region which are not currently defined
# For now, only destination buckets have notifications configured

# -------------------------------------------------------------------
# SNS topic policy – allows destination and log buckets to publish
# -------------------------------------------------------------------
resource "aws_sns_topic_policy" "allow_s3_publish_destination_replica" {
  provider = aws.replica
  arn      = aws_sns_topic.artifacts_events_replica.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "AllowS3PublishFromDestinationBucket",
        Effect   = "Allow",
        Principal = { Service = "s3.amazonaws.com" },
        Action   = "SNS:Publish",
        Resource = aws_sns_topic.artifacts_events_replica.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.destination_bucket.arn
          }
        }
      },
      {
        Sid      = "AllowS3PublishFromLogReplicaBucket",
        Effect   = "Allow",
        Principal = { Service = "s3.amazonaws.com" },
        Action   = "SNS:Publish",
        Resource = aws_sns_topic.artifacts_events_replica.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.destination_log.arn
          }
        }
      }
    ]
  })
}



# -------------------------------------------------------------------
# Delay to ensure SNS policy propagation before notification
# -------------------------------------------------------------------
resource "time_sleep" "wait_for_sns_policy" {
  depends_on = [aws_sns_topic_policy.allow_s3_publish_destination_replica]
  create_duration = "30s"
}

# -------------------------------------------------------------------
# Destination bucket notifications (replica region)
# -------------------------------------------------------------------
resource "aws_s3_bucket_notification" "destination_notifications" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_bucket.id

  topic {
    topic_arn = aws_sns_topic.artifacts_events_replica.arn
    events    = ["s3:ObjectCreated:*"]
  }

  # Ensure proper ordering
  depends_on = [
    time_sleep.wait_for_sns_policy,
    #aws_sns_topic.artifacts_events_replica,
    #aws_sns_topic_policy.allow_s3_publish_destination_replica,
    aws_s3_bucket_versioning.destination_bucket
  ]
}
