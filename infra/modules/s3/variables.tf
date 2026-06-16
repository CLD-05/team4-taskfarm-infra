variable "name_prefix" {
  description = "Prefix used for S3 bucket names, for example team4-dev or team4-prod."
  type        = string
}

variable "env" {
  description = "Environment name. dev buckets are easier to destroy."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env must be either dev or prod."
  }
}

variable "buckets" {
  description = "S3 buckets to create."
  type = map(object({
    suffix                             = string
    versioning_enabled                 = bool
    force_destroy                      = bool
    lifecycle_enabled                  = bool
    expiration_days                    = number
    noncurrent_version_expiration_days = number
  }))

  default = {
    app = {
      suffix                             = "app-bucket"
      versioning_enabled                 = true
      force_destroy                      = false
      lifecycle_enabled                  = true
      expiration_days                    = 90
      noncurrent_version_expiration_days = 30
    }
  }
}

variable "kms_key_arn" {
  description = "Optional KMS key ARN for S3 encryption. If null, SSE-S3 is used."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags for all S3 module resources."
  type        = map(string)
  default     = {}
}