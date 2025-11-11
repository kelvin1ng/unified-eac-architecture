variable "bucket_name" {
  description = "The name of the primary S3 bucket."
  type        = string
}

variable "project_tag" {
  description = "Project tag for resource grouping."
  type        = string
}

variable "replica_region" {
  description = "Destination region for replication."
  type        = string
  default     = "us-east-1"
}
