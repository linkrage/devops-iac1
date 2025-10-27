locals {
  name_prefix             = "${var.project_name}-${var.environment}"
  eks_cluster_name        = var.eks_cluster_name != null && var.eks_cluster_name != "" ? var.eks_cluster_name : format("%s-eks-%s", local.name_prefix, replace(var.eks_cluster_version, ".", "-"))
  common_tags             = { Project = var.project_name, Environment = var.environment, ManagedBy = "terraform" }
  
  # Certificate logic: prefer provided ARN, fall back to auto-created, or empty
  certificate_arn = var.alb_certificate_arn != "" ? var.alb_certificate_arn : module.acm.certificate_arn
  https_enabled   = var.enable_https && local.certificate_arn != ""
  
  cluster_admin_role_name = var.cluster_admin_role_name
  permissions_boundary_arn = var.permissions_boundary_name != "" ? format(
    "arn:%s:iam::%s:policy/%s",
    data.aws_partition.current.partition,
    data.aws_caller_identity.current.account_id,
    var.permissions_boundary_name
  ) : null
  cluster_admin_role_arn = var.cluster_admin_role_name != "" ? format(
    "arn:%s:iam::%s:role/%s",
    data.aws_partition.current.partition,
    data.aws_caller_identity.current.account_id,
    var.cluster_admin_role_name
  ) : null

  runtime_s3_bucket_arn = var.runtime_s3_bucket_name != "" ? format(
    "arn:%s:s3:::%s",
    data.aws_partition.current.partition,
    var.runtime_s3_bucket_name
  ) : null

  runtime_ssm_parameter_arns = var.runtime_ssm_parameter_prefix != "" ? [
    format(
      "arn:%s:ssm:%s:%s:parameter%s",
      data.aws_partition.current.partition,
      var.aws_region,
      data.aws_caller_identity.current.account_id,
      var.runtime_ssm_parameter_prefix
    ),
    format(
      "arn:%s:ssm:%s:%s:parameter%s*",
      data.aws_partition.current.partition,
      var.aws_region,
      data.aws_caller_identity.current.account_id,
      var.runtime_ssm_parameter_prefix
    )
  ] : []

  public_subnets = [
    for index, cidr in var.public_subnet_cidrs :
    {
      name = format("%s-public-%d", local.name_prefix, index)
      cidr = cidr
      az   = element(data.aws_availability_zones.available.names, index)
    }
  ]

  private_subnets = [
    for index, cidr in var.private_subnet_cidrs :
    {
      name = format("%s-private-%d", local.name_prefix, index)
      cidr = cidr
      az   = element(data.aws_availability_zones.available.names, index)
    }
  ]
}
