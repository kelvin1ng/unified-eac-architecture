# Optional: event notifications – CKV2_AWS_62
# Wire this to a real Lambda or SNS/SQS in future via sns_topic_arn

# Notifications for primary artifacts bucket
resource "aws_s3_bucket_notification" "artifacts_notifications" {
  bucket = aws_s3_bucket.artifacts.id

  topic {
    topic_arn = var.sns_topic_arn
    events    = ["s3:ObjectCreated:*"]
  }
}

# Notifications for log bucket
resource "aws_s3_bucket_notification" "artifacts_log_notifications" {
  bucket = aws_s3_bucket.artifacts_log.id

  topic {
    topic_arn = var.sns_topic_arn
    events    = ["s3:ObjectCreated:*"]
  }
}

data "aws_caller_identity" "current_replica" {
  provider = aws.replica
}

resource "aws_kms_key" "sns_key_replica" {
  provider                = aws.replica
  description             = "KMS key for SNS topic encryption in replica region"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current_replica.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_sns_topic" "artifacts_events_replica" {
  provider          = aws.replica
  name              = "eac-artifacts-events-replica-${var.random_suffix}"
  kms_master_key_id = aws_kms_key.sns_key_replica.arn
}

resource "aws_s3_bucket_notification" "destination_notifications" {
  provider = aws.replica
  bucket   = aws_s3_bucket.destination_bucket.id

  topic {
    topic_arn = aws_sns_topic.artifacts_events_replica.arn
    events    = ["s3:ObjectCreated:*"]
  }
  
  depends_on = [
    aws_sns_topic_policy.allow_s3_publish_destination_replica
  ]
}

# Allow S3 in replica region to publish to the replica SNS topic
resource "aws_sns_topic_policy" "allow_s3_publish_replica" {
  provider = aws.replica
  arn      = aws_sns_topic.artifacts_events_replica.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowS3PublishReplica"
        Effect   = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.artifacts_events_replica.arn
        Condition = {
          ArnLike = {
            # Only allow S3 buckets in this account/region, starting with your replica log bucket
            "aws:SourceArn" = aws_s3_bucket.destination_log.arn
          }
        }
      }
    ]
  })
}


# Allow the replica destination bucket to send events to the replica SNS topic
resource "aws_sns_topic_policy" "allow_s3_publish_destination_replica" {
  provider = aws.replica
  arn      = aws_sns_topic.artifacts_events_replica.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowS3PublishDestinationReplica"
        Effect   = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.artifacts_events_replica.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.destination_bucket.arn
          }
        }
      }
    ]
  })
}
