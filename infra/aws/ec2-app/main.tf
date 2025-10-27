data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# KMS Module for encryption
module "kms" {
  source = "./modules/kms"

  name_prefix          = local.name_prefix
  region               = var.aws_region
  tags                 = local.common_tags
  authorized_role_arns = compact([module.iam.instance_profile_role_arn, local.cluster_admin_role_arn])
  terraform_role_arn   = local.cluster_admin_role_arn
  eks_cluster_role_arn = null # Will be set after EKS module creates the role
  eks_node_role_name   = "${local.eks_cluster_name}-node-role"
}

resource "aws_s3_bucket" "runtime_config" {
  count  = var.runtime_s3_bucket_name != "" ? 1 : 0
  bucket = var.runtime_s3_bucket_name

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-runtime-config"
  })
}

resource "aws_s3_bucket_versioning" "runtime_config" {
  count  = var.runtime_s3_bucket_name != "" ? 1 : 0
  bucket = aws_s3_bucket.runtime_config[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "runtime_config" {
  count  = var.runtime_s3_bucket_name != "" ? 1 : 0
  bucket = aws_s3_bucket.runtime_config[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = module.kms.s3_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "runtime_config" {
  count  = var.runtime_s3_bucket_name != "" ? 1 : 0
  bucket = aws_s3_bucket.runtime_config[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

module "network" {
  source           = "./modules/network"
  name_prefix      = local.name_prefix
  vpc_cidr         = var.vpc_cidr
  public_subnets   = local.public_subnets
  private_subnets  = local.private_subnets
  tags             = local.common_tags
  region           = var.aws_region
  eks_cluster_name = local.eks_cluster_name
}

module "security" {
  source            = "./modules/security"
  name_prefix       = local.name_prefix
  vpc_id            = module.network.vpc_id
  alb_ingress_cidrs = ["0.0.0.0/0"]
  tags              = local.common_tags
}

module "iam" {
  source                     = "./modules/iam"
  name_prefix                = local.name_prefix
  tags                       = local.common_tags
  permissions_boundary_arn   = local.permissions_boundary_arn
  runtime_s3_bucket_arn      = local.runtime_s3_bucket_arn != null ? try(aws_s3_bucket.runtime_config[0].arn, local.runtime_s3_bucket_arn) : null
  runtime_ssm_parameter_arns = local.runtime_ssm_parameter_arns
}

module "alb" {
  source            = "./modules/alb"
  name_prefix       = local.name_prefix
  vpc_id            = module.network.vpc_id
  subnet_ids        = module.network.public_subnet_ids
  security_group_id = module.security.alb_security_group_id
  tags              = local.common_tags
  health_check_path = "/"
  enable_https      = local.https_enabled
  certificate_arn   = local.https_enabled ? var.alb_certificate_arn : ""
}

module "compute" {
  source               = "./modules/compute"
  name_prefix          = local.name_prefix
  ami_id               = var.ami_id
  instance_type        = var.instance_type
  subnet_ids           = module.network.private_subnet_ids
  security_group_ids   = [module.security.instance_security_group_id]
  iam_instance_profile = module.iam.instance_profile_name
  desired_capacity     = var.desired_capacity
  min_capacity         = var.min_capacity
  max_capacity         = var.max_capacity
  target_group_arns    = [module.alb.target_group_arn]
  tags                 = local.common_tags
  runtime_banner       = "${var.project_name} ${var.environment}"
  runtime_color        = "#0ea5e9"
  project_name         = var.project_name
  environment          = var.environment
  kms_key_id           = module.kms.ebs_key_id
}

module "eks" {
  source = "./modules/eks"
  providers = {
    kubernetes = kubernetes.eks
    helm       = helm.eks
  }

  cluster_name                          = local.eks_cluster_name
  manage_cluster                        = var.eks_manage_cluster
  cluster_iam_role_name                 = var.eks_cluster_iam_role_name
  cluster_version                       = var.eks_cluster_version
  vpc_id                                = module.network.vpc_id
  private_subnet_ids                    = module.network.private_subnet_ids
  cluster_log_types                     = var.eks_cluster_log_types
  node_instance_types                   = var.eks_node_instance_types
  node_min_size                         = var.eks_node_min_size
  node_desired_size                     = var.eks_node_desired_size
  node_max_size                         = var.eks_node_max_size
  node_disk_size                        = var.eks_node_disk_size
  node_capacity_type                    = var.eks_node_capacity_type
  node_ami_type                         = var.eks_node_ami_type
  node_iam_role_name                    = var.eks_node_iam_role_name
  node_remote_access_key_name           = var.eks_node_remote_access_key_name
  node_remote_access_security_group_ids = var.eks_node_remote_access_security_group_ids
  cluster_admin_role_arn                = local.cluster_admin_role_arn
  cluster_admin_role_name               = local.cluster_admin_role_name
  permissions_boundary_arn              = local.permissions_boundary_arn
  kms_key_id                            = module.kms.eks_key_id
  kms_key_arn                           = module.kms.eks_key_arn
  ebs_kms_key_id                        = module.kms.ebs_key_id
  logs_kms_key_id                       = module.kms.logs_key_id
  region                                = var.aws_region
  tags                                  = local.common_tags
}

data "aws_eks_cluster_auth" "staging" {
  count = var.eks_manage_cluster ? 1 : 0
  name  = module.eks.cluster_name
}
