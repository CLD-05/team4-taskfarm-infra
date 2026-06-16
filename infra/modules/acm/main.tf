# modules/acm/main.tf

resource "aws_acm_certificate" "this" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  # 와일드카드 포함 (*.taskfarm.site → argocd/grafana/www 등 서브도메인 한 번에)
  subject_alternative_names = var.subject_alternative_names

  lifecycle {
    create_before_destroy = true # 인증서 교체 시 무중단
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-cert" })
}

# DNS 검증 레코드 (Route53에 자동 생성)
resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60

  # 검증 레코드는 덮어쓰기 허용 (와일드카드+기본 도메인이 같은 레코드일 수 있음)
  allow_overwrite = true
}

# 검증 완료 대기 (레코드 생성 → ACM 확인까지)
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}
