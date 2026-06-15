variable "env" {
  type        = string
  description = "dev | prod"
}

variable "create_oidc_provider" {
  type        = bool
  default     = true
  description = "OIDC provider 생성 여부."
}

variable "name_prefix" {
  type = string
}

variable "github_org" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "ecr_repo_arns" {
  type        = list(string)
  description = "배포 대상 ECR 레포 ARN 목록 (user/admin)"
}

variable "pod_identity_roles" {
  type        = map(string) # { "alb-controller" = "정책ARN", "external-dns" = "정책ARN" }
  default     = {}
  description = "Pod Identity 역할: {역할이름 => 붙일 정책 ARN}"
}
