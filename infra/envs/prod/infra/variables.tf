# envs/prod/infra/variables.tf

variable "azs" { type = list(string) }
variable "vpc_cidr" { type = string }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "db_subnet_cidrs" { type = list(string) }

variable "github_org" { type = string }
variable "github_repo" { type = string }

variable "eks_cluster_version" {
  type    = string
  default = "1.35"
}
variable "admin_user_arns" {
  type = list(string)
}
variable "app_namespace" {
  type    = string
  default = "taskfarm"
}
variable "addon_versions" {
  type    = map(string)
  default = {}
}

variable "node_group_instance_types" {
  type    = list(string)
  default = ["m6i.large"]
}
variable "node_group_desired_size" {
  type    = number
  default = 3
}
variable "node_group_min_size" {
  type    = number
  default = 3
}
variable "node_group_max_size" {
  type    = number
  default = 8
}
variable "node_group_disk_size" {
  type    = number
  default = 50
}

variable "rds_instance_class" {
  type    = string
  default = "db.m6i.large"
}
variable "rds_replica_instance_class" {
  type    = string
  default = "db.m6i.large"
}
variable "rds_backup_retention" {
  type    = number
  default = 7
}
variable "rds_max_storage" {
  type    = number
  default = 500
}

variable "redis_node_type" {
  type    = string
  default = "cache.m7g.large"
}

variable "permissions_boundary_arn" {
  type    = string
  default = null
}

variable "rds_master_password" {
  type      = string
  sensitive = true
}
