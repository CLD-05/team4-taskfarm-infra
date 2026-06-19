# modules/cloudfront/main.tf
# CloudFront: S3 정적자원(기본) + (옵션) ALB 동적 origin.
# CloudFront용 ACM 인증서는 반드시 us-east-1. 호출 측에서 us-east-1 provider로 만든 ARN 주입.

locals {
  s3_origin_id  = "${var.name_prefix}-s3-origin"
  alb_origin_id = "${var.name_prefix}-alb-origin"
  use_alb       = var.alb_domain_name != null
}

# S3 비공개 접근용 OAC (Origin Access Control — OAI 후속 권장 방식)
resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${var.name_prefix}-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = var.aliases
  price_class         = "PriceClass_200" # 아시아 포함, 비용 절충

  # ── S3 정적 origin ──
  origin {
    domain_name              = var.static_bucket_regional_domain
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  # ── (옵션) ALB 동적 origin ──
  dynamic "origin" {
    for_each = local.use_alb ? [1] : []
    content {
      domain_name = var.alb_domain_name
      origin_id   = local.alb_origin_id
      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  # 기본: S3 정적
  default_cache_behavior {
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # (옵션) /api/* → ALB (동적, 캐시 안 함)
  dynamic "ordered_cache_behavior" {
    for_each = local.use_alb ? [1] : []
    content {
      path_pattern           = "/api/*"
      target_origin_id       = local.alb_origin_id
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods         = ["GET", "HEAD"]
      compress               = true
      forwarded_values {
        query_string = true
        headers      = ["Authorization", "Host"]
        cookies { forward = "all" }
      }
      min_ttl     = 0
      default_ttl = 0
      max_ttl     = 0
    }
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    # aliases+ACM 있으면 커스텀 인증서, 없으면 CloudFront 기본
    cloudfront_default_certificate = var.acm_certificate_arn == null
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn != null ? "sni-only" : null
    minimum_protocol_version       = var.acm_certificate_arn != null ? "TLSv1.2_2021" : "TLSv1"
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-cloudfront" })
}

# S3 버킷 정책: CloudFront(OAC)만 읽기 허용 — 호출 측 s3 모듈과 연결 필요 시 output 사용
data "aws_iam_policy_document" "s3_oac" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.static_bucket_name}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

output "distribution_id" {
  value = aws_cloudfront_distribution.this.id
}

output "distribution_domain_name" {
  description = "CloudFront 도메인 (route53 A/AAAA alias 대상)"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "distribution_hosted_zone_id" {
  description = "route53 alias용 CloudFront zone ID (고정값)"
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}

output "s3_bucket_policy_json" {
  description = "S3 버킷에 붙일 OAC 정책 (s3 모듈에 연결)"
  value       = data.aws_iam_policy_document.s3_oac.json
}
