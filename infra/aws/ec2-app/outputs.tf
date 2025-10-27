output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "alb_public_url" {
  description = "Browser-friendly URL for the Application Load Balancer."
  value       = local.https_enabled ? "https://${module.alb.alb_dns_name}" : "http://${module.alb.alb_dns_name}"
}

output "alb_zone_id" {
  value = module.alb.alb_zone_id
}

output "autoscaling_group_name" {
  value = module.compute.autoscaling_group_name
}

output "caller_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

output "eks_node_role_arn" {
  value = module.eks.node_role_arn
}

output "eks_ingress_info" {
  description = "Instructions to get the EKS ingress public URL"
  value       = "Deploy nginx: helm upgrade --install nginx apps/helm/nginx --namespace web --create-namespace -f apps/helm/nginx/values.yaml\nThen run: kubectl get ingress -n web nginx-nginx-runtime -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "acm_certificate_arn" {
  description = "ARN of the auto-created ACM certificate (if enabled)"
  value       = module.acm.certificate_arn
}

output "acm_certificate_status" {
  description = "Status of the ACM certificate"
  value       = module.acm.certificate_status
}

output "https_enabled" {
  description = "Whether HTTPS is enabled on the ALB"
  value       = local.https_enabled
}

output "certificate_domain" {
  description = "Domain name of the ACM certificate (if configured)"
  value       = module.acm.domain_name
}
