output "s3_key_id" {
  description = "KMS key ID for S3 encryption"
  value       = aws_kms_key.s3.key_id
}

output "s3_key_arn" {
  description = "KMS key ARN for S3 encryption"
  value       = aws_kms_key.s3.arn
}

output "ebs_key_id" {
  description = "KMS key ID for EBS encryption"
  value       = aws_kms_key.ebs.key_id
}

output "ebs_key_arn" {
  description = "KMS key ARN for EBS encryption"
  value       = aws_kms_key.ebs.arn
}

output "eks_key_id" {
  description = "KMS key ID for EKS secrets encryption"
  value       = aws_kms_key.eks.key_id
}

output "eks_key_arn" {
  description = "KMS key ARN for EKS secrets encryption"
  value       = aws_kms_key.eks.arn
}

# DynamoDB key managed by bootstrap layer

output "logs_key_id" {
  description = "KMS key ID for CloudWatch Logs encryption"
  value       = aws_kms_key.logs.key_id
}

output "logs_key_arn" {
  description = "KMS key ARN for CloudWatch Logs encryption"
  value       = aws_kms_key.logs.arn
}
