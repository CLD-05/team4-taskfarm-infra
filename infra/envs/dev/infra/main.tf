variable "vpc_id" {
  description = "VPC ID where dev RDS is created."
  type        = string
}

variable "db_subnet_ids" {
  description = "DB subnet IDs for dev RDS."
  type        = list(string)
}

variable "db_access_security_group_id" {
  description = "Security group ID allowed to access dev RDS."
  type        = string
}

module "rds" {
  source = "../../../modules/rds"

  name_prefix = "team4-dev"

  vpc_id                     = var.vpc_id
  db_subnet_ids              = var.db_subnet_ids
  eks_node_security_group_id = var.db_access_security_group_id

  instance_class        = "db.t4g.micro"
  allocated_storage     = 20
  max_allocated_storage = 200

  multi_az            = false
  create_read_replica = false

  deletion_protection = false
  skip_final_snapshot = true

  backup_retention_period = 1

  tags = {
    env = "dev"
  }
}
