output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "배포역할 ARN"
}

output "pod_identity_role_arns" {
  value       = { for k, r in aws_iam_role.pod_identity : k => r.arn }
  description = "역할명->ARN 맵"
}
output "oidc_provider_arn" {
  value       = local.oidc_provider_arn
  description = "OIDC ARN"
}
