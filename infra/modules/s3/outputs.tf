# modules/s3/outputs.tf

output "bucket_name" {
  description = "기본 버킷 이름 (app 키). 없으면 null."
  value       = try(aws_s3_bucket.this["app"].bucket, null)
}

output "bucket_arn" {
  description = "기본 버킷 ARN (app 키). CloudFront origin·정책에 사용. 없으면 null."
  value       = try(aws_s3_bucket.this["app"].arn, null)
}

output "bucket_id" {
  description = "기본 버킷 ID (app 키). 없으면 null."
  value       = try(aws_s3_bucket.this["app"].id, null)
}

output "bucket_names" {
  description = "버킷 이름 맵 (key => name)."
  value       = { for key, bucket in aws_s3_bucket.this : key => bucket.bucket }
}

output "bucket_arns" {
  description = "버킷 ARN 맵 (key => arn). CloudFront/IAM 연결용."
  value       = { for key, bucket in aws_s3_bucket.this : key => bucket.arn }
}

output "bucket_ids" {
  description = "버킷 ID 맵 (key => id)."
  value       = { for key, bucket in aws_s3_bucket.this : key => bucket.id }
}

# [ADD] CloudFront OAC 정책 연결용 — 정적 버킷의 regional domain name
output "bucket_regional_domain_names" {
  description = "버킷 regional domain name 맵 (CloudFront origin domain용)."
  value       = { for key, bucket in aws_s3_bucket.this : key => bucket.bucket_regional_domain_name }
}
