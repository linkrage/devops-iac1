variable "region" {
  type    = string
  default = "us-west-2"
}

variable "instance_type" {
  type    = string
  default = "t3.nano"
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "subnet_id" {
  type    = string
  default = ""
}

variable "ssh_keypair" {
  type    = string
  default = ""
}

variable "git_sha" {
  type    = string
  default = "dev"
}

variable "build_suffix" {
  type    = string
  default = ""
}

variable "kms_key_id" {
  type        = string
  default     = ""
  description = "KMS key ID for AMI encryption. If empty, uses AWS-managed key."
}

locals {
  ami_suffix = length(var.build_suffix) > 0 ? var.build_suffix : regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "al2023" {
  region = var.region

  source_ami_filter {
    filters = {
      name                = "al2023-ami-*-x86_64"
      architecture        = "x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["137112412989"]
    most_recent = true
  }

  ami_name        = "nginx-al2023-${local.ami_suffix}"
  ami_description = "Amazon Linux 2023 with nginx baked by Ansible"

  instance_type = var.instance_type
  ssh_username  = "ec2-user"

  vpc_id    = var.vpc_id != "" ? var.vpc_id : null
  subnet_id = var.subnet_id != "" ? var.subnet_id : null

  associate_public_ip_address = true
  temporary_key_pair_type     = "ed25519"

  # KMS encryption for AMI
  encrypt_boot = true
  kms_key_id   = var.kms_key_id != "" ? var.kms_key_id : null

  run_tags = {
    Name    = "packer-nginx-builder"
    GitSha  = var.git_sha
    Purpose = "image-build"
  }

  tags = {
    Component = "nginx"
    GitSha    = var.git_sha
    Source    = "packer"
  }

  iam_instance_profile = null
  ssh_keypair_name     = var.ssh_keypair != "" ? var.ssh_keypair : null
}

build {
  name    = "nginx-al2023"
  sources = ["source.amazon-ebs.al2023"]

  provisioner "shell" {
    inline = [
      "echo 'Checking for OS release updates...'",
      "LATEST_RELEASE=$(sudo dnf check-release-update 2>&1 | grep -oP 'releasever=\\K[0-9.]+' | head -1)",
      "if [ -n \"$LATEST_RELEASE\" ]; then",
      "  echo \"Upgrading to release version: $LATEST_RELEASE\"",
      "  sudo dnf upgrade -y --releasever=$LATEST_RELEASE",
      "else",
      "  echo 'Already on latest release, updating packages...'",
      "  sudo dnf upgrade -y --refresh",
      "fi",
      "echo 'Installing Ansible and dependencies...'",
      "sudo dnf install -y python3 python3-pip ansible-core"
    ]
  }

  provisioner "ansible-local" {
    playbook_file = "../ansible/packer.yml"
    role_paths    = [
      "../ansible/roles/pack",
      "../ansible/roles/fry"
    ]
    extra_arguments = [
      "--extra-vars",
      "ansible_python_interpreter=/usr/bin/python3",
      "--scp-extra-args=-O"
    ]
  }

  post-processor "manifest" {
    output = "manifest.json"
  }
}
