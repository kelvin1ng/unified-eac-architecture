# -------------------------------------------------------------------
# SNS Topic for Primary Region (artifacts and artifacts_log buckets)
# -------------------------------------------------------------------
# Note: data.aws_caller_identity.current is defined in main.tf

resource "aws_kms_key" "sns_key" {
  description             = "KMS key for SNS topic encryption in primary region"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_sns_topic" "artifacts_events" {
  name              = "eac-artifacts-events-${var.random_suffix}"
  kms_master_key_id = aws_kms_key.sns_key.arn
}

# SNS topic policy for primary region - allows artifacts and artifacts_log buckets to publish
resource "aws_sns_topic_policy" "allow_s3_publish" {
  arn = aws_sns_topic.artifacts_events.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "AllowS3PublishFromArtifactsBucket",
        Effect   = "Allow",
        Principal = { Service = "s3.amazonaws.com" },
        Action   = "SNS:Publish",
        Resource = aws_sns_topic.artifacts_events.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.artifacts.arn
          }
        }
      },
      {
        Sid      = "AllowS3PublishFromArtifactsLogBucket",
        Effect   = "Allow",
        Principal = { Service = "s3.amazonaws.com" },
        Action   = "SNS:Publish",
        Resource = aws_sns_topic.artifacts_events.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.artifacts_log.arn
          }
        }
      }
    ]
  })
}

# Delay to ensure SNS policy propagation before notification (primary region)
resource "time_sleep" "wait_for_sns_policy_primary" {
  depends_on = [aws_sns_topic_policy.allow_s3_publish]
  create_duration = "30s"
}

# Event notifications for artifacts bucket
resource "aws_s3_bucket_notification" "artifacts_notifications" {
  bucket = aws_s3_bucket.artifacts.id

  topic {
    topic_arn = aws_sns_topic.artifacts_events.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    time_sleep.wait_for_sns_policy_primary,
    aws_s3_bucket_versioning.artifacts
  ]
}

# Event notifications for artifacts_log bucket
resource "aws_s3_bucket_notification" "artifacts_log_notifications" {
  bucket = aws_s3_bucket.artifacts_log.id

  topic {
    topic_arn = aws_sns_topic.artifacts_events.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    time_sleep.wait_for_sns_policy_primary,
    aws_s3_bucket_versioning.artifacts_log
  ]
}

# -------------------------------------------------------------------
# SNS topic policy – allows destination and log buckets to publish (replica region)
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
