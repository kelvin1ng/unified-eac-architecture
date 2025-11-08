#############################################
# s3-secure module input variables
#############################################

variable "bucket_name" {
  description = "Name for the primary artifacts bucket"
  type        = string
}

variable "project_tag" {
  description = "Project tag value used on all S3 resources"
  type        = string
}

variable "random_suffix" {
  description = "Random suffix used to ensure globally unique bucket names"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic to receive S3 bucket notifications"
  type        = string
}
