variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "authorized_role_arns" {
  description = "List of IAM role ARNs authorized to use the KMS keys"
  type        = list(string)
  default     = []
}

variable "terraform_role_arn" {
  description = "IAM role ARN used by Terraform (will be granted KMS permissions)"
  type        = string
  default     = null
}

variable "eks_cluster_role_arn" {
  description = "EKS cluster IAM role ARN (will be granted KMS permissions)"
  type        = string
  default     = null
}

variable "eks_node_role_name" {
  description = "EKS node IAM role name for EBS encryption (e.g., project-eks-1-34-node-role)"
  type        = string
  default     = null
}
