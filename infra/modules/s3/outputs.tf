output "bucket_name" {
  description = "Default S3 bucket name."
  value       = aws_s3_bucket.this["app"].bucket
}

output "bucket_arn" {
  description = "Default S3 bucket ARN."
  value       = aws_s3_bucket.this["app"].arn
}

output "bucket_id" {
  description = "Default S3 bucket ID."
  value       = aws_s3_bucket.this["app"].id
}

output "bucket_names" {
  description = "S3 bucket names by key."
  value = {
    for key, bucket in aws_s3_bucket.this :
    key => bucket.bucket
  }
}

output "bucket_arns" {
  description = "S3 bucket ARNs by key."
  value = {
    for key, bucket in aws_s3_bucket.this :
    key => bucket.arn
  }
}

output "bucket_ids" {
  description = "S3 bucket IDs by key."
  value = {
    for key, bucket in aws_s3_bucket.this :
    key => bucket.id
  }
}