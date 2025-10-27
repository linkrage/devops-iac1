variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "alb_ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "ssh_ingress_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed SSH access to instances"
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
