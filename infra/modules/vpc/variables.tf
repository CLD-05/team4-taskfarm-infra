variable "env" {
  type        = string
  description = "dev | prod - NAT·컴퓨트 분기의 기준"

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env는 dev 또는 prod만 가능합니다."
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
  description = "퍼블릭 서브넷 CIDR 리스트(AZ 동적할당)."
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "프라이빗 서브넷 CIDR 리스트"
}

variable "db_subnet_cidrs" {
  type        = list(string)
  description = "DB 서브넷 CIDR 리스트"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "추가 태그 (표준4종은 provider default_tags가 부착)"
}
