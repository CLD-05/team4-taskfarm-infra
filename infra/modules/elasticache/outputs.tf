# modules/elasticache/outputs.tf

output "redis_replication_group_id" {
  description = "ElastiCache Redis replication group ID"
  value       = aws_elasticache_replication_group.redis.id
}

# Primary Endpoint => 앱이 쓰기/읽기(큐 포함) 보낼 주소
output "redis_primary_endpoint_address" {
  description = "Redis primary endpoint address (쓰기·큐). 앱이 이걸 사용."
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

# Reader Endpoint => replica(prod) 있을 때 읽기 분산용. dev 단일 노드면 없음 → null.
output "redis_reader_endpoint_address" {
  description = "Redis reader endpoint address (읽기 분산, prod replica만). dev는 null."
  value       = try(aws_elasticache_replication_group.redis.reader_endpoint_address, null)
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.redis.port
}

output "redis_security_group_id" {
  description = "Redis security group ID"
  value       = aws_security_group.redis.id
}

output "redis_subnet_group_name" {
  description = "Redis subnet group name"
  value       = aws_elasticache_subnet_group.redis.name
}
