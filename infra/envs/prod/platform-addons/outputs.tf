output "admin_mfa_role_arn" {
  description = "taskfarm-admin-sa 에 달 IRSA Role ARN"
  value       = module.platform_addons.admin_mfa_role_arn
}
