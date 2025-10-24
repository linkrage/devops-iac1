provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
    }
  }
}

provider "kubernetes" {
  alias                  = "eks"
  host                   = try(module.eks.cluster_endpoint, "https://kubernetes.docker.internal:6443")
  cluster_ca_certificate = try(base64decode(module.eks.cluster_certificate_authority_data), "")
  token                  = try(data.aws_eks_cluster_auth.staging[0].token, "dummy-token")

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      try(module.eks.cluster_name, "dummy-cluster"),
      "--region",
      var.aws_region
    ]
  }
}

provider "helm" {
  alias = "eks"
}
