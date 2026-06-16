# modules/acm/outputs.tf

output "certificate_arn" {
  description = "검증 완료된 인증서 ARN. ALB Ingress annotation 또는 CloudFront viewer_certificate에 사용."
  # validation 리소스를 거쳐서 내보냄 → 검증 완료 보장(이걸 ALB가 받으면 안전)
  value = aws_acm_certificate_validation.this.certificate_arn
}

output "domain_name" {
  description = "인증서 도메인."
  value       = aws_acm_certificate.this.domain_name
}
