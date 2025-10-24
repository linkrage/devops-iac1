variable "aws_region" {
  type        = string
  description = "AWS region for deployment."
  default     = "us-west-2"
}

variable "project_name" {
  type        = string
  description = "Project identifier used for tagging."
  default     = "a-small-ec2-app"
}

variable "environment" {
  type        = string
  description = "Environment label for tagging."
  default     = "staging"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR for the VPC."
  default     = "172.16.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets."
  default     = ["172.16.0.0/24", "172.16.1.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets."
  default     = ["172.16.100.0/24", "172.16.101.0/24"]
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the Auto Scaling Group."
  default     = "t3.nano"
}

variable "desired_capacity" {
  type        = number
  description = "Desired capacity for the Auto Scaling Group."
  default     = 2
}

variable "min_capacity" {
  type        = number
  description = "Minimum capacity for the Auto Scaling Group."
  default     = 2
}

variable "max_capacity" {
  type        = number
  description = "Maximum capacity for the Auto Scaling Group."
  default     = 4
}

variable "ami_id" {
  type        = string
  description = "AMI ID produced by Packer."
}

variable "alb_certificate_arn" {
  type        = string
  description = "Optional ACM certificate ARN for HTTPS."
  default     = ""
}

variable "enable_https" {
  type        = bool
  description = "Enable HTTPS listener on the ALB if a certificate is provided."
  default     = false
}

variable "eks_cluster_name" {
  type        = string
  description = "Name for the EKS cluster. Defaults to <project>-<environment>-eks when null."
  default     = null
}

variable "eks_manage_cluster" {
  type        = bool
  description = "Set false to reuse an existing EKS control plane instead of creating one."
  default     = true
}

variable "eks_cluster_iam_role_name" {
  type        = string
  description = "Existing IAM role name to reuse for the EKS control plane. Leave null to create a new role."
  default     = null
}

variable "eks_cluster_version" {
  type        = string
  description = "Kubernetes version for the EKS control plane."
  default     = "1.34"
}

variable "eks_node_instance_types" {
  type        = list(string)
  description = "List of instance types for the managed node group."
  default     = ["t3.small"]
}

variable "eks_node_min_size" {
  type        = number
  description = "Minimum node count for the managed node group."
  default     = 2
}

variable "eks_node_desired_size" {
  type        = number
  description = "Desired node count for the managed node group."
  default     = 2
}

variable "eks_node_max_size" {
  type        = number
  description = "Maximum node count for the managed node group."
  default     = 3
}

variable "eks_node_disk_size" {
  type        = number
  description = "Node root volume size in GiB."
  default     = 40
}

variable "eks_node_capacity_type" {
  type        = string
  description = "Capacity type for EKS nodes (ON_DEMAND or SPOT)."
  default     = "ON_DEMAND"
}

variable "eks_node_ami_type" {
  type        = string
  description = "AMI type for the EKS managed node group."
  default     = "AL2023_x86_64_STANDARD"
}

variable "eks_node_iam_role_name" {
  type        = string
  description = "Existing IAM role name to reuse for the EKS managed node group. Leave null to create a new role."
  default     = null
}

variable "eks_node_remote_access_key_name" {
  type        = string
  description = "Optional EC2 key pair name to enable SSH access to the EKS managed node group."
  default     = null
}

variable "eks_node_remote_access_security_group_ids" {
  type        = list(string)
  description = "Optional list of security group IDs allowed to reach the EKS managed nodes over SSH."
  default     = []
}

variable "eks_cluster_log_types" {
  type        = list(string)
  description = "Control plane log types to enable."
  default     = ["api", "audit", "authenticator"]
}

variable "permissions_boundary_name" {
  type        = string
  description = "Name of the IAM permissions boundary policy. ARN is derived automatically."
  default     = "terraform-managed-permissions-boundary"
}

variable "cluster_admin_role_name" {
  type        = string
  description = "Name of the IAM role granted system:masters access via aws-auth."
  default     = "terraform-deploy-role"
}

variable "runtime_s3_bucket_name" {
  type        = string
  description = "Optional S3 bucket name the runtime instances may read from."
  default     = ""
}

variable "runtime_ssm_parameter_prefix" {
  type        = string
  description = "Optional SSM parameter prefix (e.g. /app/config) accessible to runtime instances."
  default     = ""
}
