# GitHub Actions用のOIDCプロバイダー設定
resource "aws_iam_openid_connect_provider" "github_oidc" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  
  tags = {
    Name = "GitHub Actions OIDC Provider"
    Environment = "master"
    Project = "pantri-organization"
  }
}

# GitHub Actions用ロール（開発環境）
resource "aws_iam_role" "github_actions_dev" {
  name = "GitHubActions-Dev-Role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_repository}:ref:refs/heads/main",
              "repo:${var.github_repository}:pull_request"
            ]
          }
        }
      }
    ]
  })
  
  tags = {
    Environment = "dev"
    Purpose = "GitHub Actions"
    Project = "pantri-organization"
  }
}

# Dev Accountへのクロスアカウントロール引き受け権限
resource "aws_iam_role_policy" "github_actions_dev_policy" {
  name = "AssumeDevAccountRole"
  role = aws_iam_role.github_actions_dev.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = "arn:aws:iam::${var.dev_account_id}:role/TerraformExecutionRole"
      }
    ]
  })
}

# GitHub Actions用ロール（本番環境）
resource "aws_iam_role" "github_actions_prd" {
  name = "GitHubActions-Prd-Role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_repository}:ref:refs/heads/prd",
              "repo:${var.github_repository}:pull_request"
            ]
          }
        }
      }
    ]
  })
  
  tags = {
    Environment = "prd"
    Purpose = "GitHub Actions"
    Project = "pantri-organization"
  }
}

# Prd Accountへのクロスアカウントロール引き受け権限
resource "aws_iam_role_policy" "github_actions_prd_policy" {
  name = "AssumePrdAccountRole"
  role = aws_iam_role.github_actions_prd.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = "arn:aws:iam::${var.prd_account_id}:role/TerraformExecutionRole"
      }
    ]
  })
}