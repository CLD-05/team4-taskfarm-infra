variable "name_prefix" {
  description = "Name prefix for ElastiCache"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ElastiCache will be created"
  type        = string
}

variable "redis_port" {
  description = "Redis Port"
  type        = number
  default     = 6379
}

variable "app_security_group_id" {
  description = "EKS node security group id"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "db_subnet_ids" {
  description = "private subnet id for ElastiCache"
  type        = list(string)
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
  description = "redis node type"
  type        = string
}

variable "num_cache_clusters" {
  description = "redis node num"
  type        = number
  default     = 1
}

variable "automatic_failover_enabled" {
  description = "automatic failover for redis"
  type        = bool
  default     = false
}

variable "multi_az_enabled" {
  description = "Multi-AZ for redis"
  type        = bool
  default     = false
}

variable "at_rest_encryption_enabled" {
  description = "rest encryption"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "transit encryption"
  type        = bool
  # 이거 true 하면 Spring Boot Redis 클라이언트도 TLS 접속 해야 함
  default = false
}

# variable "snapshot_retention_limit" {
#   description = "Number of days to retain Redis snapshots"
#   type        = number
#   default     = 0
# }

# variable "snapshot_window" {
#   description = "time which snapstots are created"
#   type        = string
#   default     = "18:00-19:00"
# }

# variable "maintenance_window" {
#   description = "weekly time range for maintenance"
#   type        = string
#   default     = "sun:19:00-sun:20:00"
# }

# variable "apply_immediately" {
#   description = "Apply changes immediately"
#   type        = bool
#   default     = false
# }
