package aws.s3

__rego_metadata__ := {
  "id": "s3_security_best_practices",
  "title": "S3 Security Best Practices",
  "description": "Ensure S3 buckets use encryption, versioning, and logging, and block public access.",
  "custom": {
    "category": "Security",
    "severity": "high"
  }
}

# Deny if server-side encryption is missing
deny contains reason if {
  some i
  rc := input.resource_changes[i]
  rc.type == "aws_s3_bucket"

  after := rc.change.after
  not after.server_side_encryption_configuration
  reason := sprintf("S3 bucket %s must have KMS encryption enabled", [after.bucket])
}

# Deny if versioning is not enabled
deny contains msg if {
  input.resource_changes[_].type == "aws_s3_bucket"
  not input.resource_changes[_].change.after.versioning.enabled
  msg := sprintf("S3 bucket '%v' missing versioning.", [input.resource_changes[_].name])
}

# Deny if access logging is not configured
deny contains msg if {
  input.resource_changes[_].type == "aws_s3_bucket"
  not input.resource_changes[_].change.after.logging
  msg := sprintf("S3 bucket '%v' missing access logging configuration.", [input.resource_changes[_].name])
}

# Deny if public ACLs are not blocked
deny contains msg if {
  input.resource_changes[_].type == "aws_s3_bucket_public_access_block"
  input.resource_changes[_].change.after.block_public_acls != true
  msg := sprintf("Public ACLs not blocked for bucket '%v'.", [input.resource_changes[_].name])
}

deny contains msg if {
  input.resource_changes[_].type == "aws_s3_bucket_public_access_block"
  input.resource_changes[_].change.after.block_public_policy != true
  msg := sprintf("Public bucket policies not blocked for bucket '%v'.", [input.resource_changes[_].name])
}

deny contains reason if {
  some i
  rc := input.resource_changes[i]
  rc.type == "aws_s3_bucket"

  after := rc.change.after
  not after.versioning.enabled

  reason := sprintf("S3 bucket %s must have versioning enabled", [after.bucket])
}