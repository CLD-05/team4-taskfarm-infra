# modules/route53/variables.tf

variable "name_prefix" {
  description = "리소스 이름 접두사 (예: team4-prod)"
  type        = string
}

variable "domain_name" {
  description = "도메인 이름 (taskfarm.site). dev도 같은 zone을 참조하므로 동일."
  type        = string
  default     = "taskfarm.site"
}

variable "create_zone" {
  description = "Hosted Zone 생성 여부. prod=true(소유), dev=false(data 참조)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
