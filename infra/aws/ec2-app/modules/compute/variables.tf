variable "name_prefix" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "iam_instance_profile" {
  type = string
}

variable "desired_capacity" {
  type = number
}

variable "min_capacity" {
  type = number
}

variable "max_capacity" {
  type = number
}

variable "target_group_arns" {
  type = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "runtime_banner" {
  type = string
}

variable "runtime_color" {
  type = string
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "kms_key_id" {
  description = "KMS key ID for EBS volume encryption"
  type        = string
}
