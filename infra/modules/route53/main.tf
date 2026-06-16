# modules/route53/main.tf

# prod: Zone 생성
resource "aws_route53_zone" "this" {
  count = var.create_zone ? 1 : 0
  name  = var.domain_name

  tags = merge(var.tags, { Name = "${var.name_prefix}-zone" })
}

# dev: 기존 Zone(prod가 만든 것)을 이름으로 참조
data "aws_route53_zone" "this" {
  count = var.create_zone ? 0 : 1
  name  = var.domain_name
}

locals {
  zone_id      = var.create_zone ? aws_route53_zone.this[0].zone_id : data.aws_route53_zone.this[0].zone_id
  name_servers = var.create_zone ? aws_route53_zone.this[0].name_servers : data.aws_route53_zone.this[0].name_servers
}
