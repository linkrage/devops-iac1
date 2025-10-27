# Optional ACM Certificate Module
# This module creates an ACM certificate and validates it via Route53 DNS
# Only use this if you own a domain and have Route53 hosted zone

locals {
  domain_parts      = var.domain_name != "" ? split(".", var.domain_name) : []
  root_domain       = var.domain_name != "" && length(local.domain_parts) > 1 ? join(".", slice(local.domain_parts, length(local.domain_parts) - 2, length(local.domain_parts))) : ""
  create_certificate = var.domain_name != "" && var.route53_zone_id != ""
}

# ACM Certificate for the domain
resource "aws_acm_certificate" "this" {
  count = local.create_certificate ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = var.subject_alternative_names

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name   = "${var.name_prefix}-certificate"
    Domain = var.domain_name
  })
}

# DNS validation records in Route53
resource "aws_route53_record" "certificate_validation" {
  for_each = local.create_certificate ? {
    for dvo in aws_acm_certificate.this[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "this" {
  count = local.create_certificate ? 1 : 0

  certificate_arn         = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]

  timeouts {
    create = "10m"
  }
}

