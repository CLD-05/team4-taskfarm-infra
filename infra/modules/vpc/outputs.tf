# modules/vpc/outputs.tf

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
  value       = aws_db_subnet_group.this.name
  description = "RDS db subnet group 이름 (rds 모듈이 받음)"
}

# [ADD] 참고용/디버깅용 — 어느 AZ를 썼는지 명시적으로 노출
output "azs" {
  value       = local.azs
  description = "사용된 가용영역 목록"
}

# [ADD] dev NAT Instance의 보안그룹/EIP가 필요할 수 있어 노출(선택)
output "nat_instance_id" {
  value       = var.env == "dev" ? aws_instance.nat[0].id : null
  description = "dev NAT Instance ID (prod는 null)"
}
