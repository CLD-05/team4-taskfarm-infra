# 환경 디렉토리가 tfvars로 받아 모듈에 넘기는 변수들

variable "chart_versions" {
  type = map(string)
}

variable "external_secrets_secret_arns" {
  type = list(string)
}

variable "permissions_boundary_arn" {
  type = string
}

# prod 전용 (dev에선 미사용 — default로 통과)
variable "route53_hosted_zone_id" {
  type    = string
  default = null
}

variable "external_dns_domain_filters" {
  type    = list(string)
  default = []
}

variable "grafana_ingress_enabled" {
  type    = bool
  default = false
}

variable "grafana_host" {
  type    = string
  default = ""
}

variable "grafana_admin_existing_secret" {
  type    = string
  default = ""
}
