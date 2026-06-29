# envs/dev/infra/outputs.tf

output "ecr_repository_urls" {
  description = "Dev ECR repository URLs (CI/CD push 대상·EKS 이미지 경로)."
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "Dev ECR repository ARNs."
  value       = module.ecr.repository_arns
}

# platform-addons가 remote_state로 읽는 값들
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
  description = "VPC ID (ALB Controller 등)."
  value       = module.vpc.vpc_id
}

output "redis_primary_endpoint" {
  description = "Redis primary endpoint (앱 캐시·큐)."
  value       = module.elasticache.redis_primary_endpoint_address
}

output "rds_primary_endpoint" {
  description = "RDS primary endpoint (앱 DB)."
  value       = module.rds.primary_endpoint
}

output "secrets_kms_key_arn" {
  description = "Secrets Manager 암호화 KMS 키 ARN (ESO kms:Decrypt 정책용)."
  value       = module.secrets.kms_key_arn
}

output "mfa_kms_key_arn" {
  description = "어드민 MFA(TOTP) 시크릿 암호화 KMS 키 ARN. admin-sa IRSA의 kms:Encrypt/Decrypt 대상."
  value       = aws_kms_key.mfa.arn
}
