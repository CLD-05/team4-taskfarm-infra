# modules/iam/outputs.tf

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "배포역할 ARN (CI/CD가 assume)"
}

# [FIX] GitHub OIDC ARN (EKS OIDC와 헷갈리지 않게 이름 명확화)
output "github_oidc_provider_arn" {
  value       = local.github_oidc_provider_arn
  description = "GitHub Actions OIDC provider ARN"
}
