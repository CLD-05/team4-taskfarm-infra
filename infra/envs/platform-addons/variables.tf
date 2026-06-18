# platform-addons/variables.tf

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
    alb_controller   = ""       # A 담당 채움 (예: 1.8.1)
    metrics_server   = ""       # A 담당
    external_secrets = "2.6.0"  # B 담당
    external_dns     = "1.21.1" # B 담당
    argocd           = "8.5.8"  # C 담당
    kube_prometheus  = "61.7.2" # D 담당
    keda             = "2.15.1" # D 담당
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
  default     = null

  validation {
    condition     = var.env != "prod" || try(length(trimspace(var.route53_hosted_zone_id)) > 0, false)
    error_message = "prod env requires route53_hosted_zone_id."
  }
}

variable "external_dns_domain_filters" {
  description = "Domain suffixes that ExternalDNS is allowed to manage, for example example.com."
  type        = list(string)
  default     = []

  validation {
    condition     = var.env != "prod" || length(var.external_dns_domain_filters) > 0
    error_message = "prod env requires external_dns_domain_filters."
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

variable "grafana_ingress_enabled" {
  description = "Enable Grafana ingress"
  type        = bool
  default     = false
}

variable "grafana_host" {
  description = "Grafana host name"
  type        = string
  default     = ""

  validation {
    condition     = var.grafana_ingress_enabled == false || length(var.grafana_host) > 0
    error_message = "grafana_ingress_enabled가 true이면 grafana_host를 반드시 입력해야 합니다."
  }
}

variable "grafana_admin_existing_secret" {
  description = "Existing Kubernetes Secret name for Grafana admin credentials"
  type        = string
  default     = ""

  validation {
    condition     = var.env != "prod" || length(var.grafana_admin_existing_secret) > 0
    error_message = "prod 환경에서는 grafana_admin_existing_secret을 반드시 입력해야 합니다."
  }
}

variable "prometheus_retention" {
  description = "Prometheus metrics retention period"
  type        = string
  default     = "7d"
}

variable "prometheus_storage_class_name" {
  description = "StorageClass name for Prometheus EBS PV"
  type        = string
  default     = "gp3"
}

variable "prometheus_storage_size" {
  description = "Prometheus storage size"
  type        = string
  default     = "10Gi"
}

variable "grafana_admin_user_key" {
  description = "Key name for Grafana admin username in existing Secret"
  type        = string
  default     = "admin-user"
}

variable "grafana_admin_password_key" {
  description = "Key name for Grafana admin password in existing Secret"
  type        = string
  default     = "admin-password"
}

variable "enable_monitoring" {
  description = "kube-prometheus-stack(Prometheus/Grafana) 설치 여부. null이면 prod만 설치"
  type        = bool
  default     = null
}

variable "enable_keda" {
  description = "KEDA(이벤트 기반 오토스케일러) 설치 여부. AI 워커 스케일용이라 기본 true"
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "ExternalDNS 설치 여부. route53 zone이 있을 때만 의미. null이면 prod만 설치"
  type        = bool
  default     = null
}
