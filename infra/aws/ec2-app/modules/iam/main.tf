data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Cleanup existing IAM role to allow fresh creation
# This handles cases where cloud-nuke or other tools left orphaned IAM resources
resource "terraform_data" "cleanup_instance_role" {
  triggers_replace = {
    role_name = "${var.name_prefix}-instance-role"
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Detach all managed policies from role
      for policy_arn in $(aws iam list-attached-role-policies --role-name ${var.name_prefix}-instance-role --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || echo ""); do
        [ -n "$policy_arn" ] && aws iam detach-role-policy --role-name ${var.name_prefix}-instance-role --policy-arn $policy_arn 2>/dev/null || true
      done
      # Delete inline policies
      for policy_name in $(aws iam list-role-policies --role-name ${var.name_prefix}-instance-role --query 'PolicyNames[]' --output text 2>/dev/null || echo ""); do
        [ -n "$policy_name" ] && aws iam delete-role-policy --role-name ${var.name_prefix}-instance-role --policy-name $policy_name 2>/dev/null || true
      done
      # Remove role from instance profiles and delete profiles
      for profile in $(aws iam list-instance-profiles-for-role --role-name ${var.name_prefix}-instance-role --query 'InstanceProfiles[].InstanceProfileName' --output text 2>/dev/null || echo ""); do
        [ -n "$profile" ] && aws iam remove-role-from-instance-profile --instance-profile-name $profile --role-name ${var.name_prefix}-instance-role 2>/dev/null || true
        [ -n "$profile" ] && aws iam delete-instance-profile --instance-profile-name $profile 2>/dev/null || true
      done
      # Delete the role
      aws iam delete-role --role-name ${var.name_prefix}-instance-role 2>/dev/null || true
    EOT
  }
}

resource "aws_iam_role" "instance" {
  name                 = "${var.name_prefix}-instance-role"
  assume_role_policy   = data.aws_iam_policy_document.assume_ec2.json
  permissions_boundary = var.permissions_boundary_arn

  depends_on = [terraform_data.cleanup_instance_role]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-instance-role"
  })
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name_prefix}-instance-profile"
  role = aws_iam_role.instance.name
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_iam_policy_document" "runtime" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = var.runtime_s3_bucket_arn != null ? [
      var.runtime_s3_bucket_arn,
      "${var.runtime_s3_bucket_arn}/*"
    ] : ["*"]
  }

  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = length(var.runtime_ssm_parameter_arns) > 0 ? var.runtime_ssm_parameter_arns : ["*"]
  }
}

# Cleanup existing IAM policy to allow fresh creation
resource "terraform_data" "cleanup_runtime_policy" {
  triggers_replace = {
    policy_name = "${var.name_prefix}-runtime"
    account_id  = data.aws_caller_identity.current.account_id
    version     = "v2" # Increment to force cleanup to run again
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Get policy ARN
      policy_arn="arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.name_prefix}-runtime"
      # Detach from all attached entities
      for entity_arn in $(aws iam list-entities-for-policy --policy-arn $policy_arn --query 'PolicyRoles[].RoleName' --output text 2>/dev/null || echo ""); do
        [ -n "$entity_arn" ] && aws iam detach-role-policy --role-name $entity_arn --policy-arn $policy_arn 2>/dev/null || true
      done
      for entity_arn in $(aws iam list-entities-for-policy --policy-arn $policy_arn --query 'PolicyUsers[].UserName' --output text 2>/dev/null || echo ""); do
        [ -n "$entity_arn" ] && aws iam detach-user-policy --user-name $entity_arn --policy-arn $policy_arn 2>/dev/null || true
      done
      for entity_arn in $(aws iam list-entities-for-policy --policy-arn $policy_arn --query 'PolicyGroups[].GroupName' --output text 2>/dev/null || echo ""); do
        [ -n "$entity_arn" ] && aws iam detach-group-policy --group-name $entity_arn --policy-arn $policy_arn 2>/dev/null || true
      done
      # Delete all non-default versions
      for version in $(aws iam list-policy-versions --policy-arn $policy_arn --query 'Versions[?!IsDefaultVersion].VersionId' --output text 2>/dev/null || echo ""); do
        [ -n "$version" ] && aws iam delete-policy-version --policy-arn $policy_arn --version-id $version 2>/dev/null || true
      done
      # Delete the policy
      aws iam delete-policy --policy-arn $policy_arn 2>/dev/null || true
    EOT
  }
}

resource "aws_iam_policy" "runtime" {
  name        = "${var.name_prefix}-runtime"
  description = "Runtime access for application instances"
  policy      = data.aws_iam_policy_document.runtime.json

  depends_on = [terraform_data.cleanup_runtime_policy]
}

resource "aws_iam_role_policy_attachment" "runtime" {
  role       = aws_iam_role.instance.name
  policy_arn = aws_iam_policy.runtime.arn
}
