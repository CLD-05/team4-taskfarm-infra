output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC ID"
}

output "public_subnet_ids" {
  value       = [for s in aws_subnet.public : s.id]
  description = "퍼블릭 서브넷 ID 목록 (ALB 등)"
}

output "private_subnet_ids" {
  value       = [for s in aws_subnet.private : s.id]
  description = "프라이빗 서브넷 ID 목록 (EKS 노드/앱)"
}

output "db_subnet_ids" {
  value       = [for s in aws_subnet.db : s.id]
  description = "db 서브넷 ID 목록"
}

output "db_subnet_group_name" {
  value = aws_db_subnet_group.this.name
}
