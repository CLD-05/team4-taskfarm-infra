# modules/iam/variables.tf

variable "env" {
  type        = string
  description = "dev | prod"
}

variable "create_oidc_provider" {
  type        = bool
  default     = true
  description = "GitHub OIDC provider 생성 여부. 계정에 이미 있으면 false(기존 것 조회)."
}

variable "name_prefix" {
  type        = string
  description = "리소스 이름 접두사 (예: team4-dev)"
}

variable "github_org" {
  type        = string
  description = "GitHub org/owner 이름 (trust sub 클레임)"
}

variable "github_repo" {
  type        = string
  description = "GitHub repo 이름 (trust sub 클레임)"
}

variable "ecr_repo_arns" {
  type        = list(string)
  description = "배포 대상 ECR 레포 ARN 목록 (user/admin)"
}





variable "tags" {
  type        = map(string)
  default     = {}
  description = "추가 태그 (표준4종은 provider default_tags)"
}
