#platform-addons/variables.tf

variable "env" {
  description = "환경 (dev/prod). remote_state key·태그·addon 분기에 사용"
  type        = string
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
