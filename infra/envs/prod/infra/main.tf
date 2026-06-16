variable "vpc_id" {
  description = "VPC ID where prod RDS is created."
  type        = string
}

variable "db_subnet_ids" {
  description = "DB subnet IDs for prod RDS."
  type        = list(string)
}

variable "db_access_security_group_id" {
  description = "Security group ID allowed to access prod RDS."
  type        = string
}

module "ecr" {
  source = "../../../modules/ecr"

  repository_names = [
    "taskfarm-prod-user",
    "taskfarm-prod-admin"
  ]

  tags = {
    env = "prod"
  }
}

module "rds" {
  source = "../../../modules/rds"

  name_prefix = "team4-prod"

  vpc_id                     = var.vpc_id
  db_subnet_ids              = var.db_subnet_ids
  eks_node_security_group_id = var.db_access_security_group_id

  instance_class              = "db.m6i.large"
  read_replica_instance_class = "db.m6i.large"
  allocated_storage           = 100
  max_allocated_storage       = 1000

  multi_az            = true
  create_read_replica = true

  deletion_protection = true
  skip_final_snapshot = false

  backup_retention_period = 7

  tags = {
    env = "prod"
  }
}


module "eks" {
  source = "../../../modules/eks"

  endpoint_public_access  = false
  endpoint_private_access = true
  public_access_cidrs     = []
}
