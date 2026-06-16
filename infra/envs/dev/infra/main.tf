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

module "ecr" {
  source = "../../../modules/ecr"

  repository_names = [
    "taskfarm-dev-user",
    "taskfarm-dev-admin"
  ]

  tags = {
    env = "dev"
  }
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

module "eks" {
  source = "../../../modules/eks"

  endpoint_public_access  = true
  endpoint_private_access = true
  public_access_cidrs     = [" "]

  # compute_type = "fargete" 
  fargate_pod_execution_role_arn = module.iam.fargate_pod_execution_role_arn

  # 값 주입 => tfvars에 넣어도 됨
  s3_bucket_arn = module.s3.bucket_arn

  # 객체 권한 다르게 줘야 할 수도 있음
  s3_object_actions = [
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject"
  ]
}
