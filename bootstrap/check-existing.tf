# Check for existing resources that might have survived cloud-nuke
# This makes bootstrap idempotent - it will adopt existing resources instead of failing

# Try to find existing IAM policy (fails silently if not found)
data "aws_iam_policy" "permissions_boundary_existing" {
  count = local.manage_bootstrap_resources ? 1 : 0
  arn   = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/${var.permissions_boundary_name}"

  lifecycle {
    postcondition {
      condition     = self.arn != ""
      error_message = "Permissions boundary policy not found, will be created"
    }
  }
}

# Try to find existing OIDC provider
data "aws_iam_openid_connect_provider" "github_existing" {
  count = local.manage_bootstrap_resources ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"

  lifecycle {
    postcondition {
      condition     = self.arn != ""
      error_message = "OIDC provider not found, will be created"
    }
  }
}

# Try to find existing IAM role
data "aws_iam_role" "terraform_deploy_existing" {
  count = local.manage_bootstrap_resources ? 1 : 0
  name  = var.terraform_deploy_role_name

  lifecycle {
    postcondition {
      condition     = self.arn != ""
      error_message = "Terraform deploy role not found, will be created"
    }
  }
}

# Try to find existing S3 bucket
data "aws_s3_bucket" "terraform_state_existing" {
  count  = local.manage_bootstrap_resources ? 1 : 0
  bucket = var.state_bucket_name

  lifecycle {
    postcondition {
      condition     = self.bucket != ""
      error_message = "S3 bucket not found, will be created"
    }
  }
}

# Try to find existing DynamoDB table
data "aws_dynamodb_table" "terraform_locks_existing" {
  count = local.manage_bootstrap_resources ? 1 : 0
  name  = var.state_lock_table_name

  lifecycle {
    postcondition {
      condition     = self.name != ""
      error_message = "DynamoDB table not found, will be created"
    }
  }
}

# Try to find existing KMS keys via aliases
data "aws_kms_alias" "terraform_state_existing" {
  count = local.manage_bootstrap_resources ? 1 : 0
  name  = "alias/${var.project_name}-${var.environment}-terraform-state"

  lifecycle {
    postcondition {
      condition     = self.target_key_id != ""
      error_message = "KMS key for terraform state not found, will be created"
    }
  }
}

data "aws_kms_alias" "dynamodb_existing" {
  count = local.manage_bootstrap_resources ? 1 : 0
  name  = "alias/${var.project_name}-${var.environment}-dynamodb"

  lifecycle {
    postcondition {
      condition     = self.target_key_id != ""
      error_message = "KMS key for dynamodb not found, will be created"
    }
  }
}

# Locals to determine if resources already exist
locals {
  # These will be empty string if data source fails, otherwise will have value
  existing_permissions_boundary = try(data.aws_iam_policy.permissions_boundary_existing[0].arn, "")
  existing_github_oidc          = try(data.aws_iam_openid_connect_provider.github_existing[0].arn, "")
  existing_terraform_role       = try(data.aws_iam_role.terraform_deploy_existing[0].arn, "")
  existing_s3_bucket            = try(data.aws_s3_bucket.terraform_state_existing[0].id, "")
  existing_dynamodb_table       = try(data.aws_dynamodb_table.terraform_locks_existing[0].name, "")
  existing_kms_state_key        = try(data.aws_kms_alias.terraform_state_existing[0].target_key_id, "")
  existing_kms_dynamodb_key     = try(data.aws_kms_alias.dynamodb_existing[0].target_key_id, "")

  # Determine if we should create each resource (create only if doesn't exist)
  create_permissions_boundary = local.manage_bootstrap_resources && local.existing_permissions_boundary == ""
  create_github_oidc          = local.manage_bootstrap_resources && local.existing_github_oidc == ""
  create_terraform_role       = local.manage_bootstrap_resources && local.existing_terraform_role == ""
  create_s3_bucket            = local.manage_bootstrap_resources && local.existing_s3_bucket == ""
  create_dynamodb_table       = local.manage_bootstrap_resources && local.existing_dynamodb_table == ""
  create_kms_state_key        = local.manage_bootstrap_resources && local.existing_kms_state_key == ""
  create_kms_dynamodb_key     = local.manage_bootstrap_resources && local.existing_kms_dynamodb_key == ""
}
