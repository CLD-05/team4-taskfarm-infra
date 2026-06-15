variable "env" {
  type        = string
  description = "dev | prod - NAT·컴퓨트 분기의 기준"
}

variable "name_prefix" {
  type        = string
  description = "리소스 이름 접두사 (예: team4-dev)"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR. dev=10.4.0.0/17 / prod=10.4.128.0/17"
}

variable "public_subnets" {
  type        = map(string)
  description = "퍼블릭 서브넷 { AZ => CIDR }"
}

variable "private_subnets" {
  type        = map(string)
  description = "프라이빗 서브넷 { AZ => CIDR }"
}

variable "db_subnets" {
  type        = map(string)
  description = "DB 서브넷 { AZ => CIDR }"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "추가 태그 (표준4종은 provider default_tags가 부착)"
}
