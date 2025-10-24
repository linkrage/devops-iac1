variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "enable_https" {
  type    = bool
  default = false
}

variable "certificate_arn" {
  type    = string
  default = ""
}
