# envs/prod/infra/outputs.tf

output "ecr_repository_urls" {
  description = "Prod ECR repository URLs."
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "Prod ECR repository ARNs."
  value       = module.ecr.repository_arns
}

output "cluster_name" {
  description = "EKS cluster name (platform-addons provider)."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_ca" {
  description = "EKS cluster CA (base64)."
  value       = module.eks.cluster_ca
}

output "oidc_provider_arn" {
  description = "IRSA OIDC provider ARN."
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "IRSA OIDC provider URL."
  value       = module.eks.oidc_provider_url
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "redis_primary_endpoint" {
  description = "Redis primary endpoint."
  value       = module.elasticache.redis_primary_endpoint_address
}

output "rds_primary_endpoint" {
  description = "RDS primary endpoint."
  value       = module.rds.primary_endpoint
}

output "route53_name_servers" {
  description = "Route53 네임서버. 가비아 도메인 네임서버를 이 값들로 변경(수동)."
  value       = module.route53.name_servers
}

output "static_bucket_name" {
  description = "정적자원 S3 버킷 이름 (CloudFront origin)."
  value       = module.s3.bucket_name
}
