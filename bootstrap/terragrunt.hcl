locals {
  root   = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  parent = local.root.locals
}

terraform {
  source = "."
}

inputs = {
  aws_region              = local.parent.aws_region
  project_name            = local.parent.project
  environment             = local.parent.environment
  state_bucket_name       = local.parent.state_bucket_name
  state_lock_table_name   = local.parent.state_lock_table_name
  permissions_boundary_name  = local.parent.permissions_boundary_name
  terraform_deploy_role_name = local.parent.terraform_deploy_role_name
  github_org              = local.parent.github_org
  github_repo             = local.parent.github_repo
  github_ref              = local.parent.github_ref
  sso_admin_role_arns     = local.parent.sso_admin_role_name != "" ? [format("arn:aws:iam::%s:role/%s", local.parent.account_id, local.parent.sso_admin_role_name)] : []
  tags                    = {
    Project     = local.parent.project
    Environment = local.parent.environment
    ManagedBy   = "terraform"
  }
  use_existing_bootstrap_resources = try(local.parent.use_existing_bootstrap_resources, false)
}
