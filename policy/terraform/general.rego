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
  input.resource_changes[_].type == "terraform_provider"
  not input.resource_changes[_].change.after.version
  msg := sprintf("Provider '%v' missing version constraint.", [input.resource_changes[_].name])
}

# Enforce tagging on S3 buckets
deny contains msg if {
  input.resource_changes[_].type == "aws_s3_bucket"
  not input.resource_changes[_].change.after.tags.Project
  msg := sprintf("Resource '%v' missing 'Project' tag.", [input.resource_changes[_].name])
}

deny contains msg if {
  input.resource_changes[_].type == "aws_s3_bucket"
  not input.resource_changes[_].change.after.tags.Environment
  msg := sprintf("Resource '%v' missing 'Environment' tag.", [input.resource_changes[_].name])
}

# Detect potential hard-coded secrets
deny contains msg if {
  input.resource_changes[_].type == "terraform_variable"
  lower(input.resource_changes[_].change.after.default)
  contains(lower(input.resource_changes[_].change.after.default), "secret")
  msg := sprintf("Variable '%v' contains a hard-coded secret.", [input.resource_changes[_].name])
}

deny contains reason if {
  some i
  rc := input.resource_changes[i]
  rc.type == "aws_kms_key"

  after := rc.change.after

  # Policy must be present (non-empty string / object)
  not after.policy

  reason := sprintf("KMS key %s must define an explicit key policy", [rc.name])
}
