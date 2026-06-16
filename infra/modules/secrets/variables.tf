# modules/secrets/variables.tf

variable "name_prefix" {
  description = "Prefix used for Secrets Manager resource names (예: team4-dev)."
  type        = string
}

variable "env" {
  description = "Environment name. dev는 즉시 삭제(recovery 0)."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env must be either dev or prod."
  }
}

variable "secret_base_path" {
  description = "Secret 경로 베이스 (예: team4/taskfarm). 최종 경로: /base/env/name."
  type        = string
}

variable "secret_names" {
  description = "생성할 secret 이름 목록 (값은 apply 후 수동 주입)."
  type        = list(string)
  default     = ["gemini-api-key"]
}

variable "recovery_window_in_days" {
  description = "비-dev secret 복구 윈도우(일). 실수 삭제 복구용."
  type        = number
  default     = 7
}

variable "kms_deletion_window_in_days" {
  description = "KMS key deletion window in days."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Additional tags for all taggable Secrets module resources."
  type        = map(string)
  default     = {}
}
