# envs/dev/platform-addons/main.tf
module "platform_addons" {
  source = "../../../modules/platform-addons"

  env = "dev"

  # infra remote_state에서 주입
  cluster_name      = data.terraform_remote_state.infra.outputs.cluster_name
  vpc_id            = data.terraform_remote_state.infra.outputs.vpc_id
  oidc_provider_arn = data.terraform_remote_state.infra.outputs.oidc_provider_arn
  oidc_provider_url = data.terraform_remote_state.infra.outputs.oidc_provider_url

  # tfvars로 주입되는 값들
  chart_versions               = var.chart_versions
  external_secrets_secret_arns = var.external_secrets_secret_arns
  permissions_boundary_arn     = var.permissions_boundary_arn

  # dev: monitoring/external-dns 기본 off (모듈 default가 prod만)
}
