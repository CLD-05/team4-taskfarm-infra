variable "repository_names" {
  description = "ECR repository names to create, for example taskfarm-user and taskfarm-admin."
  type        = list(string)
  default     = ["taskfarm-user", "taskfarm-admin"]

  validation {
    condition     = length(var.repository_names) > 0 && length(var.repository_names) == length(distinct(var.repository_names))
    error_message = "repository_names must contain at least one unique repository name."
  }
}

variable "scan_on_push" {
  description = "Whether ECR scans images for vulnerabilities when they are pushed."
  type        = bool
  default     = true
}

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten. Use IMMUTABLE to prevent tag reuse."
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "max_image_count" {
  description = "Maximum number of recent images to keep in each repository."
  type        = number
  default     = 10

  validation {
    condition     = var.max_image_count > 0
    error_message = "max_image_count must be greater than 0."
  }
}

variable "untagged_image_expiration_days" {
  description = "Number of days to keep untagged images before lifecycle cleanup expires them."
  type        = number
  default     = 7

  validation {
    condition     = var.untagged_image_expiration_days > 0
    error_message = "untagged_image_expiration_days must be greater than 0."
  }
}

variable "tags" {
  description = "Additional tags for all ECR resources."
  type        = map(string)
  default     = {}
}
