output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github_oidc.arn
}

output "github_actions_dev_role_arn" {
  description = "ARN of the GitHub Actions role for development environment"
  value       = aws_iam_role.github_actions_dev.arn
}

output "github_actions_prd_role_arn" {
  description = "ARN of the GitHub Actions role for production environment"
  value       = aws_iam_role.github_actions_prd.arn
}