package aws.iam

__rego_metadata__ := {
  "id": "iam_least_privilege",
  "title": "IAM Least Privilege Enforcement",
  "description": "Ensure IAM roles and policies follow least-privilege principles.",
  "custom": {
    "category": "Security",
    "severity": "critical"
  }
}

# Deny policies granting full access with wildcard actions
deny contains msg if {
  input.resource_changes[_].type == "aws_iam_role_policy"
  policy := input.resource_changes[_].change.after.policy
  contains(policy, "*")
  msg := sprintf("IAM policy '%v' allows wildcard permissions.", [input.resource_changes[_].name])
}

# Deny use of AdministratorAccess
deny contains msg if {
  input.resource_changes[_].type == "aws_iam_role_policy_attachment"
  input.resource_changes[_].change.after.policy_arn
  endswith(input.resource_changes[_].change.after.policy_arn, "AdministratorAccess")
  msg := sprintf("IAM role '%v' attaches AdministratorAccess policy.", [input.resource_changes[_].name])
}
