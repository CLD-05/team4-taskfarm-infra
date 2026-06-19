# modules/platform-addons/_module_inputs.tf
# 환경 디렉토리(envs/{env}/platform-addons)에서 infra remote_state를 읽어 주입하는 값들.

variable "cluster_name" {
  description = "EKS 클러스터 이름 (infra remote_state output)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (infra remote_state output) — ALB Controller용"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN (infra remote_state output) — IRSA trust용"
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC provider URL (infra remote_state output)"
  type        = string
}
