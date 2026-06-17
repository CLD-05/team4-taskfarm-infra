#platform-addons/variables.tf

variable "env" {
  description = "환경 (dev/prod). remote_state key·태그·addon 분기에 사용"
  type        = string
}

variable "chart_versions" {
  description = "addon별 helm 차트 버전 고정값"
  type        = map(string)
  default = {
    alb_controller   = ""       # A 담당 채움 (예: 1.8.1)
    metrics_server   = ""       # A 담당
    external_secrets = ""       # B 담당
    external_dns     = ""       # B 담당
    argocd           = ""       # C 담당
    kube_prometheus  = "61.7.2" # D 담당
    keda             = "2.15.1" # D 담당
  }
}

variable "grafana_ingress_enabled" {
  description = "Enable Grafana ingress"
  type        = bool
  default     = false
}

# Grafana ingress를 켤 거면 빈값이면 안됨
variable "grafana_host" {
  description = "Grafana host name"
  type        = string
  default     = ""

  validation {
    condition     = var.grafana_ingress_enabled == false || length(var.grafana_host) > 0
    error_message = "grafana_ingress_enabled가 true이면 grafana_host를 반드시 입력해야 합니다."
  }
}

# tfvars에 반드시 입력 넣어야 함
variable "grafana_admin_existing_secret" {
  description = "Existing Kubernetes Secret name for Grafana admin credentials"
  type        = string
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
