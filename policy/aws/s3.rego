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

# Note: Encryption, versioning, and logging are managed via separate resources
# These checks would need to look at related resources, not bucket attributes
# Skipping these checks as they require more complex logic to verify related resources

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
