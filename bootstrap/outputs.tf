output "state_bucket_name" {
  description = "Name of the S3 bucket storing Terraform state."
  value       = var.state_bucket_name
}

output "state_lock_table_name" {
  description = "Name of the DynamoDB table used for state locking."
  value       = var.state_lock_table_name
}

output "permissions_boundary_arn" {
  description = "ARN of the IAM permissions boundary policy to apply to Terraform-managed roles."
  value       = local.permissions_boundary_effective_arn
}

output "terraform_deploy_role_arn" {
  description = "ARN of the IAM role assumed by Terraform executions."
  value       = local.terraform_deploy_role_arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider."
  value       = local.github_oidc_provider_effective_arn
}

output "kms_s3_key_id" {
  description = "KMS key ID for S3 encryption"
  value       = local.terraform_state_kms_key_id
}

output "kms_s3_key_arn" {
  description = "KMS key ARN for S3 encryption"
  value       = local.terraform_state_kms_key_arn
}

output "kms_dynamodb_key_id" {
  description = "KMS key ID for DynamoDB encryption"
  value       = local.dynamodb_kms_key_id
}

output "kms_dynamodb_key_arn" {
  description = "KMS key ARN for DynamoDB encryption"
  value       = local.dynamodb_kms_key_arn
}
