# modules/elasticache/variables.tf

variable "name_prefix" {
  description = "Name prefix for ElastiCache (예: team4-dev)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ElastiCache will be created"
  type        = string
}

variable "db_subnet_ids" {
  description = "private subnet ids for ElastiCache subnet group (vpc 모듈 db subnet)"
  type        = list(string)
}

variable "app_security_group_id" {
  description = "EKS node(app) security group id — 이 SG에서만 Redis 6379 허용"
  type        = string
}

variable "redis_port" {
  description = "Redis Port"
  type        = number
  default     = 6379
}

variable "redis_parameter_group_family" {
  description = "redis parameter group family"
  type        = string
  default     = "redis7"
}

variable "redis_engine_version" {
  description = "redis engine version"
  type        = string
  default     = "7.0"
}

variable "redis_node_type" {
  description = "redis node type (dev: cache.t4g.micro, prod: cache.m7g.large)"
  type        = string
}

variable "num_cache_clusters" {
  description = "redis node 개수 (dev:1, prod:2+)"
  type        = number
  default     = 1
}

variable "automatic_failover_enabled" {
  description = "automatic failover (dev:false, prod:true)"
  type        = bool
  default     = false
}

variable "multi_az_enabled" {
  description = "Multi-AZ (dev:false, prod:true)"
  type        = bool
  default     = false
}

variable "at_rest_encryption_enabled" {
  description = "at-rest encryption"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "transit(TLS) encryption. ⚠️ true면 Spring Redis 클라이언트도 TLS 접속 설정 필요."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
