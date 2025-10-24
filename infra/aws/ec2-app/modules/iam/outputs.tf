output "instance_profile_name" {
  value = aws_iam_instance_profile.this.name
}

output "role_arn" {
  value = aws_iam_role.instance.arn
}

output "instance_profile_role_arn" {
  description = "ARN of the IAM role used by the instance profile"
  value       = aws_iam_role.instance.arn
}
