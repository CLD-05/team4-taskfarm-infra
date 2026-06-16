# envs/prod/infra/main.tf

locals {
  env         = "prod"
  name_prefix = "team4-prod"
}

module "vpc" {
  source = "../../../modules/vpc"

  env                  = local.env
  name_prefix          = local.name_prefix
  azs                  = var.azs
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  db_subnet_cidrs      = var.db_subnet_cidrs
}

module "eks" {
  source = "../../../modules/eks"

  name_prefix         = local.name_prefix
  eks_cluster_version = var.eks_cluster_version
  compute_type        = "node_group"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  endpoint_public_access  = false
  endpoint_private_access = true
  public_access_cidrs     = []

  node_group_instance_types = var.node_group_instance_types
  node_group_desired_size   = var.node_group_desired_size
  node_group_min_size       = var.node_group_min_size
  node_group_max_size       = var.node_group_max_size
  node_group_disk_size      = var.node_group_disk_size

  admin_user_arns = var.admin_user_arns
  namespace       = var.app_namespace


  enable_pod_identity_s3   = false
  addon_versions           = var.addon_versions
  permissions_boundary_arn = var.permissions_boundary_arn
}

module "iam" {
  source = "../../../modules/iam"

  env                      = local.env
  name_prefix              = local.name_prefix
  github_org               = var.github_org
  github_repo              = var.github_repo
  ecr_repo_arns            = module.ecr.repository_arns
  create_oidc_provider     = false # 계정에 이미 존재
  permissions_boundary_arn = var.permissions_boundary_arn

}

module "rds" {
  source = "../../../modules/rds"

  name_prefix          = local.name_prefix
  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.db_subnet_group_name

  eks_node_security_group_id = module.eks.app_security_group_id
  bastion_security_group_id  = module.bastion.security_group_id

  instance_class              = var.rds_instance_class
  read_replica_instance_class = var.rds_replica_instance_class
  multi_az                    = true
  create_read_replica         = true
  deletion_protection         = true
  skip_final_snapshot         = false
  backup_retention_period     = var.rds_backup_retention
  max_allocated_storage       = var.rds_max_storage
}

module "bastion" {
  source = "../../../modules/bastion"

  env                      = local.env
  enabled                  = true
  vpc_id                   = module.vpc.vpc_id
  private_subnet_id        = module.vpc.private_subnet_ids[0]
  permissions_boundary_arn = var.permissions_boundary_arn
}

module "ecr" {
  source = "../../../modules/ecr"

  name_prefix      = local.name_prefix
  repository_names = ["taskfarm-user", "taskfarm-admin"]
}

module "elasticache" {
  source = "../../../modules/elasticache"

  name_prefix           = local.name_prefix
  vpc_id                = module.vpc.vpc_id
  db_subnet_ids         = module.vpc.db_subnet_ids
  app_security_group_id = module.eks.app_security_group_id

  redis_node_type            = var.redis_node_type
  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true
}

module "secrets" {
  source = "../../../modules/secrets"

  name_prefix      = local.name_prefix
  env              = local.env
  secret_base_path = "team4/taskfarm"
  secret_names     = ["gemini-api-key"]
}

# route53: prod가 zone 소유 (create_zone=true).
# apply 후 name_servers를 가비아 콘솔에 등록(수동 1회).
module "route53" {
  source = "../../../modules/route53"

  name_prefix = local.name_prefix
  domain_name = "taskfarm.site"
  create_zone = true # prod가 소유
}

# s3 정적자원 버킷 (prod만 — CloudFront origin)
module "s3" {
  source = "../../../modules/s3"

  name_prefix = local.name_prefix
  env         = local.env
  # buckets default(app)에 정적자원용. CloudFront 모듈 추가 시 OAC 연결.
}

# ── CloudFront는 추후 별도 추가 (us-east-1 ACM provider alias 필요) ──
