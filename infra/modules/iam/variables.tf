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

# ── Pod Identity (prod addon/앱용) ──
variable "pod_identity_roles" {
  type        = map(string) # { "alb-controller" = "정책ARN", ... }
  default     = {}
  description = "Pod Identity 역할: {역할이름 => 붙일 정책 ARN}. prod에서 채움. dev는 비움(Fargate 미지원)."
}

# ── [ADD] IRSA (dev addon용) ──
variable "eks_oidc_provider_arn" {
  type        = string
  default     = null
  description = "EKS OIDC provider ARN (eks 모듈 output). IRSA trust용. dev에서 필요."
}

variable "eks_oidc_provider_url" {
  type        = string
  default     = null
  description = "EKS OIDC provider URL (https:// 제외, eks 모듈 output). IRSA trust condition key용."
}

variable "irsa_roles" {
  description = <<-EOT
    IRSA 역할 정의. dev(Fargate)에서 채움. prod는 비움(Pod Identity 사용).
    각 역할은 policy_arn + 연결할 namespace/serviceaccount 필요
    (IRSA는 trust에 SA를 넣음).
    예:
      {
        alb-controller = {
          policy_arn      = "arn:...:policy/team4-dev-alb"
          namespace       = "kube-system"
          service_account = "aws-load-balancer-controller"
        }
      }
  EOT
  type = map(object({
    policy_arn      = string
    namespace       = string
    service_account = string
  }))
  default = {}
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "추가 태그 (표준4종은 provider default_tags)"
}
