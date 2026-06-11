output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC ID"
}

output "vpc_cidr" {
  value       = aws_vpc.this.cidr_block
  description = "VPC CIDR 블록"
}

output "azs" {
  value       = local.azs
  description = "동적 선택된 가용영역 목록"
}

output "igw_id" {
  value       = aws_internet_gateway.this.id
  description = "Internet Gateway ID"
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
  description = "DB 서브넷 ID 목록 (RDS/ElastiCache)"
}

output "db_subnet_group_name" {
  value       = aws_db_subnet_group.this.name
  description = "RDS 서브넷 그룹 이름 (RDS 모듈에서 사용)"
}

output "nat_gateway_ids" {
  value       = [for n in aws_nat_gateway.this : n.id]
  description = "NAT Gateway ID 목록"
}

output "public_route_table_id" {
  value       = aws_route_table.public.id
  description = "퍼블릭 라우팅 테이블 ID"
}

output "private_route_table_ids" {
  value       = [for rt in aws_route_table.private : rt.id]
  description = "프라이빗 라우팅 테이블 ID 목록"
}

output "db_route_table_id" {
  value       = aws_route_table.db.id
  description = "DB 라우팅 테이블 ID"
}
