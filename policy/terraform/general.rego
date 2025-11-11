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
  input.resource_changes[i].type == "terraform_provider"
  not input.resource_changes[i].change.after.version
  msg := sprintf("Provider '%v' missing version constraint.", [input.resource_changes[i].name])
}

# Enforce tagging on S3 buckets
deny contains msg if {
  some i
  input.resource_changes[i].type == "aws_s3_bucket"
  not input.resource_changes[i].change.after.tags.Project
  msg := sprintf("Resource '%v' missing 'Project' tag.", [input.resource_changes[i].name])
}

deny contains msg if {
  some i
  input.resource_changes[i].type == "aws_s3_bucket"
  not input.resource_changes[i].change.after.tags.Environment
  msg := sprintf("Resource '%v' missing 'Environment' tag.", [input.resource_changes[i].name])
}

# Detect potential hard-coded secrets
deny contains msg if {
  some i
  input.resource_changes[i].type == "terraform_variable"
  input.resource_changes[i].change.after.default
  contains(lower(input.resource_changes[i].change.after.default), "secret")
  msg := sprintf("Variable '%v' contains a hard-coded secret.", [input.resource_changes[i].name])
}
