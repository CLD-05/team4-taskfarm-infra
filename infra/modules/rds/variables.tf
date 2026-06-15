variable "name_prefix" {
  description = "Prefix used for RDS resource names, for example team4-dev or team4-prod."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the RDS security group is created."
  type        = string
}

variable "db_subnet_ids" {
  description = "Private DB subnet IDs for the RDS DB subnet group."
  type        = list(string)

  validation {
    condition     = length(var.db_subnet_ids) >= 2
    error_message = "At least two DB subnet IDs are required for RDS subnet group and Multi-AZ readiness."
  }
}

variable "eks_node_security_group_id" {
  description = "EKS node security group ID allowed to access MySQL on port 3306."
  type        = string
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "taskfarm"
}

variable "username" {
  description = "RDS master username. Password is managed by RDS in Secrets Manager, not by tfvars."
  type        = string
  default     = "taskfarm"
}

variable "engine_version" {
  description = "MySQL engine version."
  type        = string
  default     = "8.4"
}

variable "instance_class" {
  description = "Primary RDS instance class. Example: dev db.t4g.micro, prod db.m6i.large."
  type        = string
}

variable "read_replica_instance_class" {
  description = "Read replica instance class. Defaults to instance_class when null."
  type        = string
  default     = null
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum autoscaled storage in GB."
  type        = number

  validation {
    condition     = var.max_allocated_storage >= var.allocated_storage
    error_message = "max_allocated_storage must be greater than or equal to allocated_storage."
  }
}

variable "storage_type" {
  description = "RDS storage type."
  type        = string
  default     = "gp3"
}

variable "multi_az" {
  description = "Whether to enable Multi-AZ for the primary DB. Dev false, prod true."
  type        = bool
}

variable "create_read_replica" {
  description = "Whether to create one read replica. Dev false, prod true."
  type        = bool
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled. Dev false, prod true."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Whether to skip final snapshot on deletion. Dev true, prod false."
  type        = bool
}

variable "backup_retention_period" {
  description = "Automated backup retention period in days."
  type        = number
}

variable "backup_window" {
  description = "Preferred backup window."
  type        = string
  default     = "18:00-19:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window."
  type        = string
  default     = "sun:19:00-sun:20:00"
}

variable "port" {
  description = "MySQL port."
  type        = number
  default     = 3306
}

variable "kms_deletion_window_in_days" {
  description = "KMS key deletion window in days."
  type        = number
  default     = 7
}

variable "auto_minor_version_upgrade" {
  description = "Whether minor version upgrades are applied automatically."
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Whether changes are applied immediately."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags for all RDS module resources."
  type        = map(string)
  default     = {}
}
