# Safe existence checks using external data sources
# This provides true idempotency without failing on missing resources

locals {
  manage_bootstrap_resources = true  # Always manage bootstrap resources
  check_existing             = var.use_existing_bootstrap_resources
}

data "external" "s3_bucket_check" {
  count = local.check_existing ? 1 : 0

  program = [
    "bash", "-c",
    "if aws s3api head-bucket --bucket ${var.state_bucket_name} --region ${var.aws_region} >/dev/null 2>&1; then echo '{\"exists\":\"true\"}'; else echo '{\"exists\":\"false\"}'; fi"
  ]
}

data "external" "dynamodb_table_check" {
  count = local.check_existing ? 1 : 0

  program = [
    "bash", "-c",
    "if aws dynamodb describe-table --table-name ${var.state_lock_table_name} --region ${var.aws_region} >/dev/null 2>&1; then echo '{\"exists\":\"true\"}'; else echo '{\"exists\":\"false\"}'; fi"
  ]
}

data "external" "iam_policy_check" {
  count = local.check_existing ? 1 : 0

  program = [
    "bash", "-c",
    "if aws iam get-policy --policy-arn arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.permissions_boundary_name} --region ${var.aws_region} >/dev/null 2>&1; then echo '{\"exists\":\"true\"}'; else echo '{\"exists\":\"false\"}'; fi"
  ]
}

data "external" "oidc_provider_check" {
  count = local.check_existing ? 1 : 0

  program = [
    "bash", "-c",
    "if aws iam get-open-id-connect-provider --open-id-connect-provider-arn arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com --region ${var.aws_region} >/dev/null 2>&1; then echo '{\"exists\":\"true\"}'; else echo '{\"exists\":\"false\"}'; fi"
  ]
}

data "external" "iam_role_check" {
  count = local.check_existing ? 1 : 0

  program = [
    "bash", "-c",
    "if aws iam get-role --role-name ${var.terraform_deploy_role_name} --region ${var.aws_region} >/dev/null 2>&1; then echo '{\"exists\":\"true\"}'; else echo '{\"exists\":\"false\"}'; fi"
  ]
}

# KMS alias checks (data.aws_kms_alias doesn't fail on missing)
data "aws_kms_alias" "terraform_state_existing" {
  count = local.check_existing ? 1 : 0
  name  = "alias/${var.project_name}-${var.environment}-terraform-state"
}

data "aws_kms_alias" "dynamodb_existing" {
  count = local.check_existing ? 1 : 0
  name  = "alias/${var.project_name}-${var.environment}-dynamodb"
}

locals {
  existing_permissions_boundary = local.check_existing ? try(data.external.iam_policy_check[0].result.exists == "true" ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.permissions_boundary_name}" : "", "") : ""
  existing_github_oidc          = local.check_existing ? try(data.external.oidc_provider_check[0].result.exists == "true" ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com" : "", "") : ""
  existing_terraform_role       = local.check_existing ? try(data.external.iam_role_check[0].result.exists == "true" ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.terraform_deploy_role_name}" : "", "") : ""
  existing_s3_bucket            = local.check_existing ? try(data.external.s3_bucket_check[0].result.exists == "true" ? var.state_bucket_name : "", "") : ""
  existing_dynamodb_table       = local.check_existing ? try(data.external.dynamodb_table_check[0].result.exists == "true" ? var.state_lock_table_name : "", "") : ""
  existing_kms_state_key        = local.check_existing ? try(data.aws_kms_alias.terraform_state_existing[0].target_key_id, "") : ""
  existing_kms_dynamodb_key     = local.check_existing ? try(data.aws_kms_alias.dynamodb_existing[0].target_key_id, "") : ""

  create_permissions_boundary = local.manage_bootstrap_resources && local.existing_permissions_boundary == ""
  create_github_oidc          = local.manage_bootstrap_resources && local.existing_github_oidc == ""
  create_terraform_role       = local.manage_bootstrap_resources && local.existing_terraform_role == ""
  create_s3_bucket            = local.manage_bootstrap_resources && local.existing_s3_bucket == ""
  create_dynamodb_table       = local.manage_bootstrap_resources && local.existing_dynamodb_table == ""
  create_kms_state_key        = local.manage_bootstrap_resources && local.existing_kms_state_key == ""
  create_kms_dynamodb_key     = local.manage_bootstrap_resources && local.existing_kms_dynamodb_key == ""
}