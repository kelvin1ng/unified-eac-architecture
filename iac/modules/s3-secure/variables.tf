variable "bucket_name" {
  description = "The name of the primary S3 bucket."
  type        = string
}

variable "project_tag" {
  description = "Project tag for resources"
  type        = string
  default     = "unified-eac"
}

variable "replica_region" {
  description = "Destination region for replication."
  type        = string
  default     = "us-east-1"
}

variable "random_suffix" {
  description = "Random suffix for resource naming"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for S3 event notifications"
  type        = string
}

