variable "name_prefix" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnets" {
  description = "List of objects with cidr and az."
  type = list(object({
    name = string
    cidr = string
    az   = string
  }))
}

variable "private_subnets" {
  description = "List of objects with cidr and az."
  type = list(object({
    name = string
    cidr = string
    az   = string
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "region" {
  type = string
}

variable "eks_cluster_name" {
  type        = string
  description = "Optional EKS cluster name to apply Kubernetes subnet tags."
  default     = null
}
