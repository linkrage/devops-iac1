locals {
  tags = merge(var.tags, {
    Name      = var.cluster_name
    Component = "eks"
  })
}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "selected" {
  count = var.manage_cluster ? 0 : 1
  name  = var.cluster_name
}

data "aws_iam_role" "cluster" {
  count = var.cluster_iam_role_name != null ? 1 : 0
  name  = var.cluster_iam_role_name
}

data "aws_iam_role" "node" {
  count = var.node_iam_role_name != null ? 1 : 0
  name  = var.node_iam_role_name
}

# Cleanup existing EKS cluster IAM role to allow fresh creation
resource "terraform_data" "cleanup_cluster_role" {
  count = var.cluster_iam_role_name == null && var.manage_cluster ? 1 : 0

  triggers_replace = {
    role_name = "${var.cluster_name}-cluster-role"
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Detach all managed policies from role
      for policy_arn in $(aws iam list-attached-role-policies --role-name ${var.cluster_name}-cluster-role --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || echo ""); do
        [ -n "$policy_arn" ] && aws iam detach-role-policy --role-name ${var.cluster_name}-cluster-role --policy-arn $policy_arn 2>/dev/null || true
      done
      # Delete inline policies
      for policy_name in $(aws iam list-role-policies --role-name ${var.cluster_name}-cluster-role --query 'PolicyNames[]' --output text 2>/dev/null || echo ""); do
        [ -n "$policy_name" ] && aws iam delete-role-policy --role-name ${var.cluster_name}-cluster-role --policy-name $policy_name 2>/dev/null || true
      done
      # Delete the role
      aws iam delete-role --role-name ${var.cluster_name}-cluster-role 2>/dev/null || true
    EOT
  }
}

resource "aws_iam_role" "cluster" {
  count                = var.cluster_iam_role_name == null && var.manage_cluster ? 1 : 0
  name                 = "${var.cluster_name}-cluster-role"
  permissions_boundary = var.permissions_boundary_arn

  depends_on = [terraform_data.cleanup_cluster_role]

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

resource "aws_security_group" "cluster" {
  count       = var.manage_cluster ? 1 : 0
  name        = "${var.cluster_name}-cluster-sg"
  description = "EKS control plane security group"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "${var.cluster_name}-cluster-sg" })
}

resource "aws_security_group" "node" {
  name        = "${var.cluster_name}-node-sg"
  description = "EKS worker node security group"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "${var.cluster_name}-node-sg" })
}

resource "aws_security_group_rule" "cluster_ingress_api" {
  count                    = var.manage_cluster ? 1 : 0
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = local.cluster_security_group_id
  source_security_group_id = aws_security_group.node.id
}

resource "aws_security_group_rule" "cluster_egress_all" {
  count             = var.manage_cluster ? 1 : 0
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = local.cluster_security_group_id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "nodes_ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.node.id
  self              = true
}

resource "aws_security_group_rule" "nodes_ingress_cluster" {
  count                    = var.manage_cluster ? 1 : length(data.aws_eks_cluster.selected)
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = local.cluster_security_group_id
}

resource "aws_security_group_rule" "nodes_ingress_kubelet" {
  count                    = var.manage_cluster ? 1 : length(data.aws_eks_cluster.selected)
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = local.cluster_security_group_id
}

resource "aws_security_group_rule" "nodes_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.node.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# Cleanup existing EKS node IAM role to allow fresh creation
resource "terraform_data" "cleanup_node_role" {
  count = var.node_iam_role_name == null ? 1 : 0

  triggers_replace = {
    role_name = "${var.cluster_name}-node-role"
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Detach all managed policies from role
      for policy_arn in $(aws iam list-attached-role-policies --role-name ${var.cluster_name}-node-role --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || echo ""); do
        [ -n "$policy_arn" ] && aws iam detach-role-policy --role-name ${var.cluster_name}-node-role --policy-arn $policy_arn 2>/dev/null || true
      done
      # Delete inline policies
      for policy_name in $(aws iam list-role-policies --role-name ${var.cluster_name}-node-role --query 'PolicyNames[]' --output text 2>/dev/null || echo ""); do
        [ -n "$policy_name" ] && aws iam delete-role-policy --role-name ${var.cluster_name}-node-role --policy-name $policy_name 2>/dev/null || true
      done
      # Remove role from instance profiles and delete profiles
      for profile in $(aws iam list-instance-profiles-for-role --role-name ${var.cluster_name}-node-role --query 'InstanceProfiles[].InstanceProfileName' --output text 2>/dev/null || echo ""); do
        [ -n "$profile" ] && aws iam remove-role-from-instance-profile --instance-profile-name $profile --role-name ${var.cluster_name}-node-role 2>/dev/null || true
        [ -n "$profile" ] && aws iam delete-instance-profile --instance-profile-name $profile 2>/dev/null || true
      done
      # Delete the role
      aws iam delete-role --role-name ${var.cluster_name}-node-role 2>/dev/null || true
    EOT
  }
}

resource "aws_iam_role" "node" {
  count                = var.node_iam_role_name == null ? 1 : 0
  name                 = "${var.cluster_name}-node-role"
  permissions_boundary = var.permissions_boundary_arn

  depends_on = [terraform_data.cleanup_node_role]

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

locals {
  cluster_role_name = try(aws_iam_role.cluster[0].name, data.aws_iam_role.cluster[0].name)
  cluster_role_arn  = try(aws_iam_role.cluster[0].arn, data.aws_iam_role.cluster[0].arn)
  node_role_name    = try(aws_iam_role.node[0].name, data.aws_iam_role.node[0].name)
  node_role_arn     = try(aws_iam_role.node[0].arn, data.aws_iam_role.node[0].arn)
  cluster_security_group_id = coalesce(
    try(aws_security_group.cluster[0].id, null),
    try(data.aws_eks_cluster.selected[0].vpc_config[0].cluster_security_group_id, null)
  )
  cluster_endpoint = coalesce(
    try(aws_eks_cluster.this[0].endpoint, null),
    try(data.aws_eks_cluster.selected[0].endpoint, null)
  )
  cluster_ca_data = coalesce(
    try(aws_eks_cluster.this[0].certificate_authority[0].data, null),
    try(data.aws_eks_cluster.selected[0].certificate_authority[0].data, null)
  )
  cluster_oidc_issuer = coalesce(
    try(aws_eks_cluster.this[0].identity[0].oidc[0].issuer, null),
    try(data.aws_eks_cluster.selected[0].identity[0].oidc[0].issuer, null)
  )
  cluster_name    = var.cluster_name
  oidc_issuer_url = local.cluster_oidc_issuer
  oidc_provider_arn = var.manage_cluster ? (
    try(aws_iam_openid_connect_provider.cluster[0].arn, "")
    ) : (
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(local.cluster_oidc_issuer, "https://", "")}"
  )
  aws_auth_roles = concat(
    [
      {
        rolearn  = local.node_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes"
        ]
      }
    ],
    var.cluster_admin_role_arn == null ? [] : [
      {
        rolearn  = var.cluster_admin_role_arn
        username = coalesce(var.cluster_admin_role_name, "cluster-admin")
        groups = [
          "system:masters"
        ]
      }
    ]
  )
}

resource "kubernetes_config_map_v1" "aws_auth" {
  provider = kubernetes

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(local.aws_auth_roles)
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_iam_role_policy_attachment.cluster_vpc,
    aws_eks_cluster.this
  ]
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = local.cluster_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_vpc" {
  role       = local.cluster_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = local.node_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = local.node_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_registry" {
  role       = local.node_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "null_resource" "cluster_version_trigger" {
  count = var.manage_cluster ? 1 : 0

  triggers = {
    k8s_version = var.cluster_version
  }
}

resource "aws_eks_cluster" "this" {
  count    = var.manage_cluster ? 1 : 0
  name     = var.cluster_name
  role_arn = local.cluster_role_arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [local.cluster_security_group_id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  dynamic "encryption_config" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      provider {
        key_arn = var.kms_key_arn
      }
      resources = ["secrets"]
    }
  }

  enabled_cluster_log_types = var.cluster_log_types
  tags                      = local.tags

  lifecycle {
    replace_triggered_by = [null_resource.cluster_version_trigger[0]]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_iam_role_policy_attachment.cluster_vpc
  ]
}

data "tls_certificate" "cluster" {
  count = var.manage_cluster ? 1 : 0
  url   = aws_eks_cluster.this[0].identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  count           = var.manage_cluster ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this[0].identity[0].oidc[0].issuer
  tags            = local.tags
}

resource "aws_eks_node_group" "default" {
  cluster_name = coalesce(
    try(aws_eks_cluster.this[0].name, null),
    var.cluster_name
  )
  node_group_name = "${var.cluster_name}-default"
  node_role_arn   = local.node_role_arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.node_instance_types
  capacity_type   = var.node_capacity_type

  scaling_config {
    min_size     = var.node_min_size
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  dynamic "remote_access" {
    for_each = var.node_remote_access_key_name != null || length(var.node_remote_access_security_group_ids) > 0 ? [1] : []
    content {
      ec2_ssh_key               = var.node_remote_access_key_name
      source_security_group_ids = var.node_remote_access_security_group_ids
    }
  }

  tags = local.tags

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_registry,
    kubernetes_config_map_v1.aws_auth,
    aws_eks_cluster.this
  ]
}

# Launch template for EKS nodes with KMS-encrypted EBS volumes
resource "aws_launch_template" "node" {
  name_prefix = "${var.cluster_name}-node-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.node_disk_size
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = var.ebs_kms_key_id != null && var.ebs_kms_key_id != ""
      kms_key_id            = var.ebs_kms_key_id != null && var.ebs_kms_key_id != "" ? var.ebs_kms_key_id : null
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tags, { Name = "${var.cluster_name}-node" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.tags, { Name = "${var.cluster_name}-node-volume" })
  }
}

data "aws_iam_policy_document" "lb_controller_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(local.oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(local.oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Cleanup existing LB controller IAM role to allow fresh creation
resource "terraform_data" "cleanup_lb_controller_role" {
  triggers_replace = {
    role_name = "${var.cluster_name}-lb-controller-role"
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Detach all managed policies from role
      for policy_arn in $(aws iam list-attached-role-policies --role-name ${var.cluster_name}-lb-controller-role --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || echo ""); do
        [ -n "$policy_arn" ] && aws iam detach-role-policy --role-name ${var.cluster_name}-lb-controller-role --policy-arn $policy_arn 2>/dev/null || true
      done
      # Delete inline policies
      for policy_name in $(aws iam list-role-policies --role-name ${var.cluster_name}-lb-controller-role --query 'PolicyNames[]' --output text 2>/dev/null || echo ""); do
        [ -n "$policy_name" ] && aws iam delete-role-policy --role-name ${var.cluster_name}-lb-controller-role --policy-name $policy_name 2>/dev/null || true
      done
      # Delete the role
      aws iam delete-role --role-name ${var.cluster_name}-lb-controller-role 2>/dev/null || true
    EOT
  }
}

resource "aws_iam_role" "lb_controller" {
  name                 = "${var.cluster_name}-lb-controller-role"
  assume_role_policy   = data.aws_iam_policy_document.lb_controller_assume.json
  permissions_boundary = var.permissions_boundary_arn
  tags                 = local.tags

  depends_on = [terraform_data.cleanup_lb_controller_role]
}

# Cleanup existing LB controller IAM policy to allow fresh creation
resource "terraform_data" "cleanup_lb_controller_policy" {
  triggers_replace = {
    policy_name = "${var.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
    account_id  = data.aws_caller_identity.current.account_id
    version     = "v2" # Increment to force cleanup to run again
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Get policy ARN
      policy_arn="arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
      # Detach from all attached entities
      for entity_arn in $(aws iam list-entities-for-policy --policy-arn $policy_arn --query 'PolicyRoles[].RoleName' --output text 2>/dev/null || echo ""); do
        [ -n "$entity_arn" ] && aws iam detach-role-policy --role-name $entity_arn --policy-arn $policy_arn 2>/dev/null || true
      done
      for entity_arn in $(aws iam list-entities-for-policy --policy-arn $policy_arn --query 'PolicyUsers[].UserName' --output text 2>/dev/null || echo ""); do
        [ -n "$entity_arn" ] && aws iam detach-user-policy --user-name $entity_arn --policy-arn $policy_arn 2>/dev/null || true
      done
      for entity_arn in $(aws iam list-entities-for-policy --policy-arn $policy_arn --query 'PolicyGroups[].GroupName' --output text 2>/dev/null || echo ""); do
        [ -n "$entity_arn" ] && aws iam detach-group-policy --group-name $entity_arn --policy-arn $policy_arn 2>/dev/null || true
      done
      # Delete all non-default versions
      for version in $(aws iam list-policy-versions --policy-arn $policy_arn --query 'Versions[?!IsDefaultVersion].VersionId' --output text 2>/dev/null || echo ""); do
        [ -n "$version" ] && aws iam delete-policy-version --policy-arn $policy_arn --version-id $version 2>/dev/null || true
      done
      # Delete the policy
      aws iam delete-policy --policy-arn $policy_arn 2>/dev/null || true
    EOT
  }
}

resource "aws_iam_policy" "lb_controller" {
  name        = "${var.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/lb_controller_policy.json")
  tags        = local.tags

  depends_on = [terraform_data.cleanup_lb_controller_policy]
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

resource "kubernetes_service_account_v1" "lb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.lb_controller.arn
    }
  }

  depends_on = [aws_eks_node_group.default]
}

# Install AWS Load Balancer Controller via Helm CLI
# This approach is more reliable than helm provider with dynamic cluster configuration
resource "null_resource" "lb_controller_install" {
  triggers = {
    cluster_endpoint = local.cluster_endpoint
    cluster_name     = local.cluster_name
    version          = "1.7.0"
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Update kubeconfig for the EKS cluster
      aws eks update-kubeconfig --name ${local.cluster_name} --region ${var.region} --alias ${local.cluster_name}
      
      # Add helm repo if not already added
      helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
      helm repo update
      
      # Install or upgrade the AWS Load Balancer Controller
      helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        --namespace kube-system \
        --version 1.7.0 \
        --set clusterName=${local.cluster_name} \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set region=${var.region} \
        --set vpcId=${var.vpc_id} \
        --wait
    EOT

    environment = {
      AWS_DEFAULT_REGION = var.region
    }
  }

  depends_on = [
    kubernetes_service_account_v1.lb_controller,
    aws_iam_role_policy_attachment.lb_controller,
    aws_eks_node_group.default
  ]
}

# Nginx app is deployed separately via Helm CLI
# Run: helm upgrade --install nginx apps/helm/nginx --namespace web --create-namespace -f apps/helm/nginx/values.yaml
