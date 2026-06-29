
# [MFA] 모듈 안 IRSA Role ARN을 envs 레벨로 노출 (terraform output 으로 보이게)
output "admin_mfa_role_arn" {
  description = "taskfarm-admin-sa 에 달 IRSA Role ARN"
  value       = module.platform_addons.admin_mfa_role_arn
}
