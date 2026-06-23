# envs/prod/infra/cloudfront.tf
# CloudFront + us-east-1 ACM(acm 모듈 재사용) + route53 alias.
# 기존 module.s3(정적 버킷, "app" 키) / module.route53(zone) 연결.

# ⚠️ CloudFront ACM은 반드시 us-east-1. 별도 provider alias.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags {
    tags = {
      Team = "team4"
      env  = "prod"
    }
  }
}

# CloudFront용 인증서 — 기존 acm 모듈 재사용 (us-east-1 provider 주입)
module "acm_cloudfront" {
  source = "../../../modules/acm"

  providers = {
    aws = aws.us_east_1 # ← CloudFront ACM은 us-east-1
  }

  name_prefix               = "${local.name_prefix}-cloudfront"
  domain_name               = "taskfarm.site"
  subject_alternative_names = ["www.taskfarm.site"]
  zone_id                   = module.route53.zone_id
}

# CloudFront 배포 — 기존 cloudfront 모듈 호출
module "cloudfront" {
  source = "../../../modules/cloudfront"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  name_prefix = local.name_prefix

  # 정적 버킷은 "app" 키 (s3 모듈 default)
  static_bucket_name            = module.s3.bucket_names["app"]
  static_bucket_regional_domain = module.s3.bucket_regional_domain_names["app"]

  aliases             = ["taskfarm.site", "www.taskfarm.site"]
  acm_certificate_arn = module.acm_cloudfront.certificate_arn

  # 앱(동적) origin: ingress ALB는 동적 생성이라 일단 정적만.
  #   2차로 ALB DNS 확보 후: alb_domain_name = "<prod ingress ALB DNS>"

  tags = { Name = "${local.name_prefix}-cloudfront" }
}

# 정적 버킷 정책: CloudFront(OAC)만 GetObject 허용
resource "aws_s3_bucket_policy" "static_cloudfront" {
  bucket = module.s3.bucket_ids["app"]
  policy = module.cloudfront.s3_bucket_policy_json
}

# route53: taskfarm.site → CloudFront alias
resource "aws_route53_record" "cf_root" {
  zone_id = module.route53.zone_id
  name    = "taskfarm.site"
  type    = "A"
  alias {
    name                   = module.cloudfront.distribution_domain_name
    zone_id                = module.cloudfront.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cf_www" {
  zone_id = module.route53.zone_id
  name    = "www.taskfarm.site"
  type    = "A"
  alias {
    name                   = module.cloudfront.distribution_domain_name
    zone_id                = module.cloudfront.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

output "cloudfront_domain" {
  value = module.cloudfront.distribution_domain_name
}
