# modules/ecr/outputs.tf

output "repository_names" {
  description = "생성된 ECR 레포 전체 이름 (team4-{env}-... 형태)."
  value       = [for repo in aws_ecr_repository.this : repo.name]
}

output "repository_urls" {
  description = "레포 URL 맵 (짧은이름 => URL). CI/CD push 대상·EKS 이미지 경로."
  value       = { for short, repo in aws_ecr_repository.this : short => repo.repository_url }
}

output "repository_arns" {
  description = "레포 ARN 리스트. iam 모듈의 ecr_repo_arns(ECR push 권한)로 주입."
  value       = [for repo in aws_ecr_repository.this : repo.arn]
}

output "repository_arn_map" {
  description = "레포 ARN 맵 (짧은이름 => ARN)."
  value       = { for short, repo in aws_ecr_repository.this : short => repo.arn }
}
