# modules/route53/outputs.tf

output "zone_id" {
  description = "Hosted Zone ID. acm 모듈(검증 레코드)·ExternalDNS(IAM 정책)가 사용."
  value       = local.zone_id
}

output "name_servers" {
  description = "AWS 네임서버 4개. ⚠️ 가비아 콘솔에 이 값들을 네임서버로 등록(수동 1회)."
  value       = local.name_servers
}

output "domain_name" {
  description = "도메인 이름."
  value       = var.domain_name
}
