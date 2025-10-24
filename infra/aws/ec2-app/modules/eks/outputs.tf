output "cluster_name" {
  value = var.cluster_name
}

output "cluster_endpoint" {
  value = local.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = local.cluster_ca_data
}

output "cluster_oidc_issuer_url" {
  value = local.cluster_oidc_issuer
}

output "cluster_security_group_id" {
  value = local.cluster_security_group_id
}

output "node_security_group_id" {
  value = aws_security_group.node.id
}

output "node_role_arn" {
  value = local.node_role_arn
}
