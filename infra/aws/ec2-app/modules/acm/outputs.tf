output "certificate_arn" {
  description = "ARN of the ACM certificate (empty if not created)"
  value       = length(aws_acm_certificate.this) > 0 ? aws_acm_certificate.this[0].arn : ""
}

output "certificate_status" {
  description = "Status of the ACM certificate"
  value       = length(aws_acm_certificate.this) > 0 ? aws_acm_certificate.this[0].status : "NOT_CREATED"
}

output "domain_name" {
  description = "Domain name of the certificate"
  value       = var.domain_name
}

output "certificate_domain_validation_options" {
  description = "Domain validation options for the certificate"
  value       = length(aws_acm_certificate.this) > 0 ? aws_acm_certificate.this[0].domain_validation_options : []
}

