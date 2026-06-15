variable "name_prefix" {
  description = "Prefix used for Secrets Manager resource names, for example team4-dev or team4-prod."
  type        = string
}

variable "env" {
  description = "Environment name. Dev uses immediate secret deletion."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env must be either dev or prod."
  }
}

variable "secret_base_path" {
  description = "Base path for Secrets Manager secret names, for example team4/taskfarm."
  type        = string
}

variable "secret_names" {
  description = "Secret names to create under secret_base_path/env."
  type        = list(string)

  default = [
    "gemini-api-key"
  ]
}

variable "recovery_window_in_days" {
  description = "Recovery window in days for non-dev secrets."
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
