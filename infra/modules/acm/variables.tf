# modules/acm/variables.tf

variable "name_prefix" {
  description = "리소스 이름 접두사 (예: team4-prod 또는 team4-prod-cloudfront)"
  type        = string
}

variable "domain_name" {
  description = "인증서 주 도메인 (taskfarm.site)"
  type        = string
}

variable "subject_alternative_names" {
  description = "추가 도메인(SAN). 와일드카드로 서브도메인 커버 (예: [*.taskfarm.site])."
  type        = list(string)
  default     = []
}

variable "zone_id" {
  description = "DNS 검증 레코드를 넣을 Route53 Hosted Zone ID (route53 모듈 output)."
  type        = string
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
