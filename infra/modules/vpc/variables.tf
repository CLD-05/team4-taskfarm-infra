# modules/vpc/variables.tf

variable "env" {
  type        = string
  description = "dev | prod - NAT·컴퓨트 분기의 기준"

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env는 dev 또는 prod만 가능합니다."
  }
}

# [ADD] AZ 명시 주입. ap-northeast-2b는 서울 구형 AZ라 미사용(강사 지침) → a,c만.
variable "azs" {
  type        = list(string)
  description = "사용할 가용영역 목록. 서울은 2b(구형) 제외하고 [2a, 2c] 사용. 서브넷 CIDR 리스트와 순서·개수 일치 필요."

  validation {
    condition     = length(var.azs) >= 1 && !contains(var.azs, "ap-northeast-2b")
    error_message = "azs는 최소 1개이며 ap-northeast-2b(구형 AZ)는 사용할 수 없습니다. (a, c 사용)"
  }
}

variable "name_prefix" {
  type        = string
  description = "리소스 이름 접두사 (예: team4-dev)"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR. dev=10.4.0.0/17 / prod=10.4.128.0/17"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "퍼블릭 서브넷 CIDR 리스트. ⚠️ dev도 2개(2a,2c) 필요 — ALB가 최소 2개 AZ 요구. var.azs와 순서 일치."
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "프라이빗 서브넷 CIDR 리스트(/20 권장 — Pod IP 여유). var.azs와 순서 일치."
}

variable "db_subnet_cidrs" {
  type        = list(string)
  description = "DB 서브넷 CIDR 리스트. var.azs와 순서 일치."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "추가 태그 (표준4종은 provider default_tags가 부착)"
}
