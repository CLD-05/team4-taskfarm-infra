# envs/dev/infra/variables.tf

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
variable "public_access_cidrs" {
  type    = list(string)
  default = []
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

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.micro"
}
variable "rds_backup_retention" {
  type    = number
  default = 1
}
variable "rds_max_storage" {
  type    = number
  default = 100
}

variable "redis_node_type" {
  type    = string
  default = "cache.t4g.micro"
}
