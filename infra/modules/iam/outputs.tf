# modules/iam/outputs.tf

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "배포역할 ARN (CI/CD가 assume)"
}

output "pod_identity_role_arns" {
  value       = { for k, r in aws_iam_role.pod_identity : k => r.arn }
  description = "Pod Identity 역할명->ARN 맵 (prod. eks pod_identity_association에 연결)"
}

# [ADD] IRSA role ARN 맵 (dev. platform-addons가 helm serviceAccount annotation에 사용)
output "irsa_role_arns" {
  value       = { for k, r in aws_iam_role.irsa : k => r.arn }
  description = "IRSA 역할명->ARN 맵 (dev. SA annotation eks.amazonaws.com/role-arn)"
}

# [FIX] GitHub OIDC ARN (EKS OIDC와 헷갈리지 않게 이름 명확화)
output "github_oidc_provider_arn" {
  value       = local.github_oidc_provider_arn
  description = "GitHub Actions OIDC provider ARN"
}
