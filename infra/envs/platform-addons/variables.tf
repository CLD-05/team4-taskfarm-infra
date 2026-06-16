#platform-addons/variables.tf

variable "env" {
  description = "환경 (dev/prod). remote_state key·태그·addon 분기에 사용"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env must be either dev or prod."
  }
}

variable "chart_versions" {
  description = "addon별 helm 차트 버전 고정값"
  type        = map(string)
  default = {
    alb_controller   = "" # A 담당 채움 (예: 1.8.1)
    metrics_server   = "" # A 담당
    external_secrets = "" # B 담당
    external_dns     = "" # B 담당
    argocd           = "" # C 담당
    kube_prometheus  = "" # D 담당
    keda             = "" # D 담당
  }
}

variable "external_secrets_secret_arns" {
  description = "Secrets Manager secret ARNs that External Secrets Operator is allowed to read."
  type        = list(string)

  validation {
    condition     = length(var.external_secrets_secret_arns) > 0
    error_message = "external_secrets_secret_arns must contain at least one Secrets Manager secret ARN."
  }
}

variable "route53_hosted_zone_id" {
  description = "Route53 hosted zone ID that ExternalDNS is allowed to manage."
  type        = string

  validation {
    condition     = length(trimspace(var.route53_hosted_zone_id)) > 0
    error_message = "route53_hosted_zone_id must not be empty."
  }
}

variable "external_dns_domain_filters" {
  description = "Domain suffixes that ExternalDNS is allowed to manage, for example example.com."
  type        = list(string)

  validation {
    condition     = length(var.external_dns_domain_filters) > 0
    error_message = "external_dns_domain_filters must contain at least one domain."
  }
}

locals {
  name_prefix       = "team4-${var.env}"
  oidc_provider_arn = data.terraform_remote_state.infra.outputs.oidc_provider_arn
  oidc_provider_url = trimprefix(
    try(
      data.terraform_remote_state.infra.outputs.oidc_provider_url,
      trimprefix(local.oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/")
    ),
    "https://"
  )
}
