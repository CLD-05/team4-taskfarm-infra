variable "name_prefix" {
  description = "Resource name prefix."
  type        = string
}

variable "github_owner" {
  description = "GitHub repository owner or org."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name that contains the prod deploy workflow."
  type        = string
}

variable "github_workflow_id" {
  description = "Workflow file name or workflow ID to dispatch."
  type        = string
  default     = "cd.yml"
}

variable "github_prod_input_name" {
  description = "Boolean workflow_dispatch input name used to trigger prod deployment."
  type        = string
  default     = "deploy_prod"
}

variable "github_ref" {
  description = "Git ref used for workflow dispatch."
  type        = string
  default     = "main"
}

variable "github_environment_name" {
  description = "GitHub Actions environment name to approve through pending deployments."
  type        = string
  default     = "production"
}

variable "github_token_secret_name" {
  description = "Secrets Manager secret name containing a GitHub token with Actions write permission."
  type        = string
}

variable "github_token_secret_arn" {
  description = "Secrets Manager secret ARN containing a GitHub token with Actions write permission."
  type        = string
}

variable "slack_signing_secret_name" {
  description = "Secrets Manager secret name containing the Slack signing secret."
  type        = string
}

variable "slack_signing_secret_arn" {
  description = "Secrets Manager secret ARN containing the Slack signing secret."
  type        = string
}

variable "allowed_slack_user_ids" {
  description = "Slack user IDs allowed to request or approve prod deployment."
  type        = list(string)
  default     = []
}

variable "secret_kms_key_arn" {
  description = "Optional KMS key ARN used by the Secrets Manager secrets."
  type        = string
  default     = null
}

variable "permissions_boundary_arn" {
  description = "Optional IAM permissions boundary ARN."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags for taggable resources."
  type        = map(string)
  default     = {}
}
