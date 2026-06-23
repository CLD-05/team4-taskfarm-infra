# envs/prod/platform-addons/main.tf
module "platform_addons" {
  source = "../../../modules/platform-addons"

  env = "prod"

  cluster_name        = data.terraform_remote_state.infra.outputs.cluster_name
  vpc_id              = data.terraform_remote_state.infra.outputs.vpc_id
  oidc_provider_arn   = data.terraform_remote_state.infra.outputs.oidc_provider_arn
  oidc_provider_url   = data.terraform_remote_state.infra.outputs.oidc_provider_url
  secrets_kms_key_arn = data.terraform_remote_state.infra.outputs.secrets_kms_key_arn

  chart_versions               = var.chart_versions
  external_secrets_secret_arns = var.external_secrets_secret_arns
  permissions_boundary_arn     = var.permissions_boundary_arn

  # prod: monitoring/external-dns 필수값
  route53_hosted_zone_id        = var.route53_hosted_zone_id
  external_dns_domain_filters   = var.external_dns_domain_filters
  grafana_ingress_enabled       = var.grafana_ingress_enabled
  grafana_host                  = var.grafana_host
  grafana_admin_existing_secret = var.grafana_admin_existing_secret
}
