variable "name_prefix" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "permissions_boundary_arn" {
  type    = string
  default = null
}

variable "runtime_s3_bucket_arn" {
  type    = string
  default = null
}

variable "runtime_ssm_parameter_arns" {
  type    = list(string)
  default = []
}
