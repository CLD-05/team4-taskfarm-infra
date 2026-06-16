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
    alb_controller   = ""      # A 담당
    metrics_server   = ""      # A 담당
    external_secrets = ""      # B 담당
    external_dns     = ""      # B 담당
    argocd           = "8.5.8" # C 담당
    kube_prometheus  = ""      # D 담당
    keda             = ""      # D 담당
  }
}

variable "argocd_config_repo_url" {
  description = "ArgoCD가 감시할 config repo URL"
  type        = string
  default     = "https://github.com/CLD-05/team4-taskfarm-config.git"
}

variable "argocd_config_repo_path" {
  description = "Config repo 안에서 root Application이 바라볼 경로"
  type        = string
  default     = "argocd"
}

variable "argocd_target_revision" {
  description = "ArgoCD가 추적할 config repo revision"
  type        = string
  default     = "main"
}