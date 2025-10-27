provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  kms_alias_names = {
    terraform_state = "alias/${var.project_name}-${var.environment}-terraform-state"
    dynamodb        = "alias/${var.project_name}-${var.environment}-dynamodb"
  }

  permissions_boundary_arn = format(
    "arn:%s:iam::%s:policy/%s",
    data.aws_partition.current.partition,
    data.aws_caller_identity.current.account_id,
    var.permissions_boundary_name
  )

  github_oidc_provider_arn = format(
    "arn:%s:iam::%s:oidc-provider/token.actions.githubusercontent.com",
    data.aws_partition.current.partition,
    data.aws_caller_identity.current.account_id
  )
}
# KMS Key for Terraform State S3 Bucket
resource "aws_kms_key" "terraform_state" {
  count = local.create_kms_state_key ? 1 : 0

  description             = "KMS key for Terraform state S3 bucket encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(local.base_tags, {
    Name    = "${var.project_name}-${var.environment}-terraform-state-kms"
    Purpose = "terraform-state-encryption"
  })
}

resource "aws_kms_alias" "terraform_state" {
  count = local.create_kms_state_key ? 1 : 0

  name          = local.kms_alias_names.terraform_state
  target_key_id = aws_kms_key.terraform_state[0].key_id
}

resource "aws_kms_key_policy" "terraform_state" {
  count = local.create_kms_state_key ? 1 : 0

  key_id = aws_kms_key.terraform_state[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Terraform Deploy Role"
        Effect = "Allow"
        Principal = {
          AWS = local.terraform_deploy_role_arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# KMS Key for DynamoDB Table
resource "aws_kms_key" "dynamodb" {
  count = local.create_kms_dynamodb_key ? 1 : 0

  description             = "KMS key for Terraform locks DynamoDB table encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(local.base_tags, {
    Name    = "${var.project_name}-${var.environment}-dynamodb-kms"
    Purpose = "dynamodb-encryption"
  })
}

resource "aws_kms_alias" "dynamodb" {
  count = local.create_kms_dynamodb_key ? 1 : 0

  name          = local.kms_alias_names.dynamodb
  target_key_id = aws_kms_key.dynamodb[0].key_id
}

resource "aws_kms_key_policy" "dynamodb" {
  count = local.create_kms_dynamodb_key ? 1 : 0

  key_id = aws_kms_key.dynamodb[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow DynamoDB to use the key"
        Effect = "Allow"
        Principal = {
          Service = "dynamodb.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Terraform Deploy Role"
        Effect = "Allow"
        Principal = {
          AWS = local.terraform_deploy_role_arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}



locals {
  # Use existing resources if found, otherwise use newly created ones
  terraform_state_kms_key_id         = local.existing_kms_state_key != "" ? local.existing_kms_state_key : try(aws_kms_key.terraform_state[0].key_id, "")
  terraform_state_kms_key_arn        = local.existing_kms_state_key != "" ? "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/${local.existing_kms_state_key}" : try(aws_kms_key.terraform_state[0].arn, "")
  dynamodb_kms_key_id                = local.existing_kms_dynamodb_key != "" ? local.existing_kms_dynamodb_key : try(aws_kms_key.dynamodb[0].key_id, "")
  dynamodb_kms_key_arn               = local.existing_kms_dynamodb_key != "" ? "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/${local.existing_kms_dynamodb_key}" : try(aws_kms_key.dynamodb[0].arn, "")
  terraform_state_bucket_id          = local.existing_s3_bucket != "" ? local.existing_s3_bucket : try(aws_s3_bucket.terraform_state[0].id, "")
  terraform_state_bucket_arn         = local.existing_s3_bucket != "" ? "arn:aws:s3:::${local.existing_s3_bucket}" : try(aws_s3_bucket.terraform_state[0].arn, "")
  terraform_locks_table_arn          = local.existing_dynamodb_table != "" ? "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${local.existing_dynamodb_table}" : try(aws_dynamodb_table.terraform_locks[0].arn, "")
  permissions_boundary_effective_arn = local.existing_permissions_boundary != "" ? local.existing_permissions_boundary : try(aws_iam_policy.permissions_boundary[0].arn, "")
  github_oidc_provider_effective_arn = local.existing_github_oidc != "" ? local.existing_github_oidc : try(aws_iam_openid_connect_provider.github[0].arn, "")
  terraform_deploy_role_arn          = local.existing_terraform_role != "" ? local.existing_terraform_role : try(aws_iam_role.terraform_deploy[0].arn, "")
}

resource "aws_s3_bucket" "terraform_state" {
  count = local.create_s3_bucket ? 1 : 0

  bucket = var.state_bucket_name
  tags   = local.base_tags
}


resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = local.terraform_state_bucket_id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = local.terraform_state_bucket_id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = local.terraform_state_kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = local.terraform_state_bucket_id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "terraform_state_bucket" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [
      local.terraform_state_bucket_arn,
      "${local.terraform_state_bucket_arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "AllowTerraformRoleBucket"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.terraform_deploy_role_arn]
    }
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      local.terraform_state_bucket_arn
    ]
  }

  statement {
    sid    = "AllowTerraformRoleObjects"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.terraform_deploy_role_arn]
    }
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion"
    ]
    resources = [
      "${local.terraform_state_bucket_arn}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = local.terraform_state_bucket_id
  policy = data.aws_iam_policy_document.terraform_state_bucket.json
}

resource "aws_dynamodb_table" "terraform_locks" {
  count = local.create_dynamodb_table ? 1 : 0

  name         = var.state_lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = local.base_tags
}


data "aws_iam_policy_document" "permissions_boundary" {
  statement {
    sid    = "ScopedServiceAccess"
    effect = "Allow"
    actions = [
      "autoscaling:*",
      "ec2:*",
      "elasticloadbalancing:*",
      "eks:*",
      "logs:*",
      "ssm:*"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  statement {
    sid    = "S3AndDynamoDB"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:ListBucket",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:Scan",
      "dynamodb:UpdateItem",
      "dynamodb:DescribeTable"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "KMSAccess"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant",
      "kms:ListAliases",
      "kms:ListKeys"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IAMManagement"
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:AttachRolePolicy",
      "iam:AddRoleToInstanceProfile",
      "iam:CreateRole",
      "iam:CreateInstanceProfile",
      "iam:DeleteRole",
      "iam:DeleteInstanceProfile",
      "iam:DeleteRolePermissionsBoundary",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:PassRole",
      "iam:PutRolePermissionsBoundary",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:TagPolicy",
      "iam:UntagRole",
      "iam:UntagPolicy",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:ListInstanceProfiles",
      "iam:ListInstanceProfilesForRole",
      "iam:GetInstanceProfile",
      "iam:SimulatePrincipalPolicy",
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "RequireProjectTagOnCreate"
    effect = "Deny"
    actions = [
      "autoscaling:CreateAutoScalingGroup",
      "autoscaling:CreateLaunchConfiguration",
      "elasticloadbalancing:Create*",
      "ec2:Create*",
      "eks:CreateCluster",
      "eks:CreateNodegroup",
      "iam:CreateRole"
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/Project"
      values   = ["true"]
    }
    condition {
      test     = "StringNotLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::*:role/*-lb-controller-role"]
    }
  }

  statement {
    sid    = "EnforcePermissionsBoundary"
    effect = "Deny"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePermissionsBoundary",
      "iam:UpdateRole"
    ]
    resources = ["*"]
    condition {
      test     = "StringNotEquals"
      variable = "iam:PermissionsBoundary"
      values = [
        format(
          "arn:%s:iam::%s:policy/%s",
          data.aws_partition.current.partition,
          data.aws_caller_identity.current.account_id,
          var.permissions_boundary_name
        )
      ]
    }
  }
}

resource "aws_iam_policy" "permissions_boundary" {
  count       = local.create_permissions_boundary ? 1 : 0
  name        = var.permissions_boundary_name
  description = "Permissions boundary applied to Terraform-managed IAM roles."
  policy      = data.aws_iam_policy_document.permissions_boundary.json
  tags        = local.base_tags
}


resource "aws_iam_openid_connect_provider" "github" {
  count           = local.create_github_oidc ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = [local.github_oidc_audience]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = local.base_tags
}


data "aws_iam_policy_document" "terraform_deploy_assume_role" {
  dynamic "statement" {
    for_each = length(var.sso_admin_role_arns) > 0 ? [1] : []
    content {
      sid    = "AllowAdministrators"
      effect = "Allow"
      actions = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
      principals {
        type        = "AWS"
        identifiers = var.sso_admin_role_arns
      }
    }
  }

  statement {
    sid     = "AllowGitHubOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_effective_arn]
    }
    dynamic "condition" {
      for_each = flatten([
        for test, variables in local.github_oidc_conditions : [
          for variable, values in variables : {
            test     = test
            variable = variable
            values   = values
          }
        ]
      ])
      content {
        test     = condition.value.test
        variable = condition.value.variable
        values   = condition.value.values
      }
    }
  }
}

data "aws_iam_policy_document" "terraform_deploy_inline" {
  statement {
    sid    = "StateBackend"
    effect = "Allow"
    actions = [
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:Scan",
      "dynamodb:UpdateItem",
      "dynamodb:DescribeTable"
    ]
    resources = [local.terraform_locks_table_arn]
  }

  statement {
    sid    = "StateBucket"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:GetObjectVersion",
      "s3:DeleteObjectVersion"
    ]
    resources = [
      local.terraform_state_bucket_arn,
      "${local.terraform_state_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "InfrastructureServices"
    effect = "Allow"
    actions = [
      "autoscaling:*",
      "ec2:*",
      "elasticloadbalancing:*",
      "eks:CreateCluster",
      "eks:DeleteCluster",
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:ListNodegroups",
      "eks:ListUpdates",
      "eks:UpdateClusterConfig",
      "eks:UpdateClusterVersion",
      "eks:TagResource",
      "eks:UntagResource",
      "eks:DescribeUpdate",
      "eks:CreateNodegroup",
      "eks:DeleteNodegroup",
      "eks:DescribeNodegroup",
      "eks:UpdateNodegroupConfig",
      "eks:UpdateNodegroupVersion"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  statement {
    sid    = "IAMManagement"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:AddRoleToInstanceProfile",
      "iam:CreateRole",
      "iam:CreateInstanceProfile",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeleteRole",
      "iam:DeleteInstanceProfile",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:DeleteRolePermissionsBoundary",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetInstanceProfile",
      "iam:ListPolicyVersions",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfiles",
      "iam:ListInstanceProfilesForRole",
      "iam:ListRolePolicies",
      "iam:PassRole",
      "iam:PutRolePermissionsBoundary",
      "iam:PutRolePolicy",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagRole",
      "iam:TagPolicy",
      "iam:UntagRole",
      "iam:UntagPolicy",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ServiceLinkedRoleManagement"
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
      "iam:DeleteServiceLinkedRole",
      "iam:GetServiceLinkedRoleDeletionStatus"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values = [
        "eks.amazonaws.com",
        "eks-nodegroup.amazonaws.com",
        "elasticloadbalancing.amazonaws.com",
        "autoscaling.amazonaws.com"
      ]
    }
  }

  statement {
    sid    = "KMSManagement"
    effect = "Allow"
    actions = [
      "kms:CreateKey",
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListAliases",
      "kms:ListKeys",
      "kms:ListResourceTags",
      "kms:PutKeyPolicy",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:UpdateAlias",
      "kms:UpdateKeyDescription",
      "kms:EnableKeyRotation",
      "kms:DisableKeyRotation",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:RetireGrant",
      "kms:RevokeGrant",
      "kms:ListGrants"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "terraform_deploy" {
  count                = local.create_terraform_role ? 1 : 0
  name                 = var.terraform_deploy_role_name
  assume_role_policy   = data.aws_iam_policy_document.terraform_deploy_assume_role.json
  permissions_boundary = local.permissions_boundary_effective_arn
  max_session_duration = 3600
  tags                 = local.base_tags
}


resource "aws_iam_role_policy" "terraform_deploy" {
  name   = "terraform-deploy-inline"
  role   = var.terraform_deploy_role_name
  policy = data.aws_iam_policy_document.terraform_deploy_inline.json
}
