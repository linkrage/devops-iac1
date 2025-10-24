locals {
  base_tags = merge({
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }, var.tags)

  github_oidc_audience = "sts.amazonaws.com"

  github_oidc_conditions = {
    "StringEquals" = {
      "token.actions.githubusercontent.com:aud" = [local.github_oidc_audience]
    }
    "StringLike" = {
      "token.actions.githubusercontent.com:sub" = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}
