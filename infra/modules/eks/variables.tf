# modules/eks/variables.tf

variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (EKS 보안그룹 생성용)"
  type        = string
}

variable "eks_cluster_version" {
  description = "EKS version"
  type        = string
  default     = "1.35"
}

variable "enabled_cluster_log_types" {
  description = "EKS control plane log types"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "private_subnet_ids" {
  description = "connected private subnet id"
  type        = list(string)
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "endpoint_public_access" {
  description = "public access"
  type        = bool
}

variable "endpoint_private_access" {
  description = "private access"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "public endpoint 접근 허용 CIDR. public access 끄면 빈 리스트."
  default     = []
}

variable "node_group_disk_size" {
  description = "Disk size for EKS worker nodes"
  type        = number
  default     = 20
}

variable "node_group_instance_types" {
  description = "EC2 instance types"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 0 # [FIX] dev(Fargate)에선 미사용 → default 줘서 미주입 허용
}

variable "node_group_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 0
}

variable "node_group_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 0
}

variable "admin_user_arns" {
  description = "EKS cluster admin으로 등록할 IAM 유저 ARN 목록. 전원 동등하게 cluster admin. 가이드 09-1(3)."
  type        = list(string)
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN (Pod Identity S3 접근용)"
  type        = string
  default     = "" # [FIX] pod identity 안 쓰면 미주입 허용
}

variable "s3_object_actions" {
  description = "S3 object-level actions (Pod Identity 정책)"
  type        = list(string)
  default     = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
  # [NOTE] dev/prod tfvars에서 환경별로 다르게 줄 수 있음. 기본은 객체 RW.
}

variable "namespace" {
  description = "앱 namespace (Fargate profile / Pod Identity 대상)"
  type        = string
}

variable "service_account" {
  description = "앱 serviceAccount (Pod Identity 대상)"
  type        = string
  default     = ""
}

variable "compute_type" {
  description = "Compute type for EKS workloads. fargate or node_group"
  type        = string

  validation {
    condition     = contains(["fargate", "node_group"], var.compute_type)
    error_message = "compute_type must be either fargate or node_group."
  }
}

# [FIX] 이름 통일: enable_pod_identity_s3 (main.tf locals도 이 이름으로 맞춤)
variable "enable_pod_identity_s3" {
  description = "Pod Identity S3 리소스 생성 여부. node_group일 때만 true 권장(Fargate는 pod-identity-agent 미지원)."
  type        = bool
  default     = false
}

# ── [ADD] EKS Add-on 버전 (버전 고정 — 재현성) ──
# 비우면 EKS가 클러스터 버전에 맞는 default를 씀. 운영은 고정 권장.
variable "addon_versions" {
  description = "EKS managed add-on 버전 고정값. 빈 문자열이면 EKS default 사용."
  type        = map(string)
  default = {
    vpc_cni            = ""
    coredns            = ""
    kube_proxy         = ""
    ebs_csi_driver     = ""
    pod_identity_agent = ""
  }
}

variable "permissions_boundary_arn" {
  description = "IAM Role에 강제할 permissions boundary ARN (부트캠프 계정 정책). 없으면 null."
  type        = string
  default     = null
}
