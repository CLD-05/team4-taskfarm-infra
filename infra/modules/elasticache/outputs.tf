output "redis_replication_group_id" {
  description = "ElastiCache Redis replication group ID"
  value       = aws_elasticache_replication_group.redis.id
}

# Redis Primary Endpoint => 애플리케이션이 redis에 쓰기/읽기 요청을 보낼 주소
output "redis_primary_endpoint_address" {
  description = "Redis primary endpoint address"
  # dev 단일 노드에서 이 값이 없으면 에러가 날 수도 있음
  value = try(aws_elasticache_replication_group.redis.reader_endpoint_address, null)
}

# Redis Reader Endpoint => replica가 있는 경우 읽기 분산에 사용할 수 있는 주소
output "redis_reader_endpoint_address" {
  description = "Redis reader endpoint address"
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
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
