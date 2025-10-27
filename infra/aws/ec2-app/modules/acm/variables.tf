variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "domain_name" {
  type        = string
  description = "Primary domain name for the ACM certificate (e.g., app.example.com). Leave empty to skip certificate creation."
  default     = ""
}

variable "subject_alternative_names" {
  type        = list(string)
  description = "Additional domain names for the certificate (e.g., [\"*.example.com\"])"
  default     = []
}

variable "route53_zone_id" {
  type        = string
  description = "Route53 hosted zone ID for DNS validation. Required if domain_name is provided."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

