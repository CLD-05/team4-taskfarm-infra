variable "name" {
  type        = string
  description = "리소스 이름 접두사 (예: team1-dev). 규약 prefix teamN- 기준"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR 블록. 팀별 고유 대역 10.N.0.0/16 (team1=10.1.0.0/16)"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr은 유효한 CIDR이어야 합니다 (예: 10.1.0.0/16)."
  }
}

variable "az_count" {
  type        = number
  default     = 1
  description = "사용할 AZ 개수. dev=1, prod=2. AZ는 data source로 동적 선택(letter 하드코딩 금지)"

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 4
    error_message = "az_count는 1~4 사이여야 합니다 (ap-northeast-2 가용영역 범위)."
  }
}

variable "enable_nat_gateway" {
  type        = bool
  default     = true
  description = "NAT Gateway 생성 여부"
}

variable "single_nat_gateway" {
  type        = bool
  default     = true
  description = "true=NAT 1개만(기본, EIP 쿼터·비용 절감), false=AZ마다 NAT(prod 고가용성)"
}

variable "eks_cluster_name" {
  type        = string
  default     = ""
  description = "EKS 클러스터 이름. 지정 시 서브넷에 kubernetes.io/cluster/<name> 태그 부착. 비우면 생략"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "추가 태그. 표준 4종(Team/Environment/Project/Owner)은 provider default_tags가 부착하므로 여기 넣지 말 것"
}
