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
  reason := sprintf("S3 bucket '%v' must have KMS encryption enabled.", [after.bucket])
}

# Deny if versioning is not enabled
deny contains msg if {
  some i
  rc := input.resource_changes[i]
  rc.type == "aws_s3_bucket"
  not rc.change.after.versioning.enabled
  msg := sprintf("S3 bucket '%v' missing versioning.", [rc.name])
}

# Deny if access logging is not configured
deny contains msg if {
  some i
  rc := input.resource_changes[i]
  rc.type == "aws_s3_bucket"
  not rc.change.after.logging
  msg := sprintf("S3 bucket '%v' missing access logging configuration.", [rc.name])
}

# Deny if public ACLs are not blocked
deny contains msg if {
  some i
  rc := input.resource_changes[i]
  rc.type == "aws_s3_bucket_public_access_block"
  rc.change.after.block_public_acls != true
  msg := sprintf("Public ACLs not blocked for bucket '%v'.", [rc.name])
}

# Deny if public bucket policies are not blocked
deny contains msg if {
  some i
  rc := input.resource_changes[i]
  rc.type == "aws_s3_bucket_public_access_block"
  rc.change.after.block_public_policy != true
  msg := sprintf("Public bucket policies not blocked for bucket '%v'.", [rc.name])
}

# Duplicate versioning check (kept but unified safely)
deny contains reason if {
  some i
  rc := input.resource_changes[i]
  rc.type == "aws_s3_bucket"
  after := rc.change.after
  not after.versioning.enabled
  reason := sprintf("S3 bucket '%v' must have versioning enabled.", [after.bucket])
}
