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
  some i
  rc := input.resource_changes[i]
  rc.type == "aws_iam_role_policy"

  policy := rc.change.after.policy
  contains(policy, "*")

  msg := sprintf("IAM policy '%v' allows wildcard permissions.", [rc.name])
}

# Deny use of AdministratorAccess
deny contains msg if {
  some i
  rc := input.resource_changes[i]
  rc.type == "aws_iam_role_policy_attachment"

  policy_arn := rc.change.after.policy_arn
  policy_arn != null
  endswith(policy_arn, "AdministratorAccess")

  msg := sprintf("IAM role '%v' attaches AdministratorAccess policy.", [rc.name])
}
