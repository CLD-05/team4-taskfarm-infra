# modules/cloudfront/variables.tf
variable "name_prefix" {
  type = string
}

variable "static_bucket_name" {
  description = "정적자원 S3 버킷 이름 (origin)"
  type        = string
}

variable "static_bucket_regional_domain" {
  description = "S3 버킷 regional domain name (예: team4-prod-static.s3.ap-northeast-2.amazonaws.com)"
  type        = string
}

variable "aliases" {
  description = "CloudFront 대체 도메인 (CNAME). 예: [\"taskfarm.site\"]. 비우면 *.cloudfront.net만."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "us-east-1의 ACM 인증서 ARN. aliases 쓸 때 필수. 없으면 CloudFront 기본 인증서."
  type        = string
  default     = null
}

variable "alb_domain_name" {
  description = "동적(앱) origin ALB 도메인. 지정 시 /api/* 등을 ALB로 보냄. 없으면 S3 정적만."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
