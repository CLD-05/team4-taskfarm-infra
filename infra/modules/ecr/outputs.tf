output "repository_names" {
  description = "Created ECR repository names."
  value       = [for repo in aws_ecr_repository.this : repo.name]
}

output "repository_urls" {
  description = "Repository URL map keyed by repository name. Use these values in GitHub Actions push targets and EKS image paths."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "repository_arns" {
  description = "Repository ARN list for IAM policies that need ECR push permissions."
  value       = [for repo in aws_ecr_repository.this : repo.arn]
}

output "repository_arn_map" {
  description = "Repository ARN map keyed by repository name."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.arn }
}
