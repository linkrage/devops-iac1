variable "cluster_name" {
  type = string
}

variable "manage_cluster" {
  type        = bool
  default     = true
  description = "Set to false to reuse an existing EKS control plane instead of creating one."
}

variable "cluster_version" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "cluster_log_types" {
  type = list(string)
}

variable "node_instance_types" {
  type = list(string)
}

variable "node_min_size" {
  type = number
}

variable "node_desired_size" {
  type = number
}

variable "node_max_size" {
  type = number
}

variable "node_disk_size" {
  type = number
}

variable "node_capacity_type" {
  type = string
}

variable "node_ami_type" {
  type        = string
  default     = "AL2023_x86_64_STANDARD"
  description = "AMI type for managed node groups. Defaults to the latest Amazon Linux 2023 image family."
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "permissions_boundary_arn" {
  type    = string
  default = null
}

variable "cluster_iam_role_name" {
  type        = string
  default     = null
  description = "Reuse an existing IAM role for the EKS control plane when provided."

  validation {
    condition     = !(var.manage_cluster == false && var.cluster_iam_role_name == null)
    error_message = "cluster_iam_role_name must be set when manage_cluster is false."
  }
}

variable "node_iam_role_name" {
  type        = string
  default     = null
  description = "Reuse an existing IAM role for the EKS worker nodes when provided."
}

variable "node_remote_access_key_name" {
  type        = string
  default     = null
  description = "Optional EC2 key pair name to enable SSH remote access to managed nodes. Leave null to disable remote access."
}

variable "node_remote_access_security_group_ids" {
  type        = list(string)
  default     = []
  description = "Optional list of security group IDs permitted to access managed nodes over SSH."
}

variable "cluster_admin_role_arn" {
  type        = string
  default     = null
  description = "IAM role ARN granted system:masters in aws-auth."
}

variable "cluster_admin_role_name" {
  type        = string
  default     = null
  description = "Username to associate with the cluster admin role in aws-auth."
}

variable "kms_key_id" {
  description = "KMS key ID for EKS secrets encryption"
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "KMS key ARN for EKS secrets encryption"
  type        = string
  default     = null
}

variable "ebs_kms_key_id" {
  description = "KMS key ID for EBS volume encryption on nodes"
  type        = string
  default     = null
}

variable "logs_kms_key_id" {
  description = "KMS key ID for CloudWatch Logs encryption"
  type        = string
  default     = null
}

variable "region" {
  description = "AWS region for EKS cluster"
  type        = string
}
