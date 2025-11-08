package terraform.general

__rego_metadata__ := {
  "id": "terraform_governance_baseline",
  "title": "Terraform Governance Baseline",
  "description": "Ensure Terraform follows organizational tagging and secret management policies.",
  "custom": {
    "category": "Governance",
    "severity": "medium"
  }
}

# Enforce provider version constraint
deny contains msg if {
  some i
  rc := input.resource_changes[i]
  rc.type == "terraform_provider"
  not rc.change.after.version
  msg := sprintf("Provider '%v' missing version constraint.", [rc.name])
}

# Enforce Project tag on S3 buckets
deny contains msg if {
  some i
  rc := input.resource_changes[i]
  rc.type == "aws_s3_bucket"
  not rc.change.after.tags.Project
  msg := sprintf("Resource '%v' missing 'Project' tag.", [rc.name])
}

# Enforce Environment tag on S3 buckets
deny contains msg if {
  some i
  rc := input.resource_changes[i]
  rc.type == "aws_s3_bucket"
  not rc.change.after.tags.Environment
  msg := sprintf("Resource '%v' missing 'Environment' tag.", [rc.name])
}

# Detect potential hard-coded secrets
deny contains msg if {
  some i
  rc := input.resource_changes[i]
  rc.type == "terraform_variable"
  val := lower(rc.change.after.default)
  contains(val, "secret")
  msg := sprintf("Variable '%v' contains a hard-coded secret.", [rc.name])
}

# Ensure KMS key defines a policy
deny contains reason if {
  some i
  rc := input.resource_changes[i]
  rc.type == "aws_kms_key"
  after := rc.change.after
  not after.policy
  reason := sprintf("KMS key '%v' must define an explicit key policy.", [rc.name])
}
