output "ecr_repository_urls" {
  description = "Prod ECR repository URLs for GitHub Actions push targets and EKS image paths."
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "Prod ECR repository ARNs for IAM push permissions."
  value       = module.ecr.repository_arns
}
