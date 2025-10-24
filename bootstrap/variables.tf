variable "aws_region" {
  type        = string
  description = "AWS region where the bootstrap resources will be created."
}

variable "project_name" {
  type        = string
  description = "Short identifier applied to all bootstrap resources and tags."
}

variable "environment" {
  type        = string
  description = "Environment label (e.g. staging) used for tagging."
}

variable "state_bucket_name" {
  type        = string
  description = "Globally unique name for the Terraform state S3 bucket."
}

variable "state_lock_table_name" {
  type        = string
  description = "Name of the DynamoDB table used for Terraform state locking."
}

variable "terraform_deploy_role_name" {
  type        = string
  description = "Name of the IAM role assumed by Terraform (locally and via CI)."
  default     = "terraform-deploy-role"
}

variable "permissions_boundary_name" {
  type        = string
  description = "Name for the IAM permissions boundary policy Terraform-managed roles must use."
  default     = "terraform-managed-permissions-boundary"
}

variable "sso_admin_role_arns" {
  type        = list(string)
  description = "List of IAM role ARNs allowed to assume the terraform deploy role (e.g. AWS SSO administrator roles)."
  default     = []
}

variable "github_org" {
  type        = string
  description = "GitHub organisation or user that owns the repository."
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (without organisation)."
}

variable "github_ref" {
  type        = string
  description = "Git reference that is allowed to assume the terraform deploy role via OIDC."
  default     = "refs/heads/main"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags applied to bootstrap resources."
  default     = {}
}

variable "use_existing_bootstrap_resources" {
  type        = bool
  description = "Set to true to reuse pre-existing bootstrap resources (KMS aliases, state bucket, DynamoDB table, IAM policy, etc.) instead of creating them."
  default     = false
}
