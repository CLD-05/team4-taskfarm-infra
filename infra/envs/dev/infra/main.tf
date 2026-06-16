# envs/dev/infra/main.tf

locals {
  env         = "dev"
  name_prefix = "team4-dev"
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
  compute_type        = "fargate"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  endpoint_public_access  = true
  endpoint_private_access = true
  public_access_cidrs     = var.public_access_cidrs

  admin_user_arns = var.admin_user_arns
  namespace       = var.app_namespace

  enable_pod_identity_s3 = false
  addon_versions         = var.addon_versions
}

module "iam" {
  source = "../../../modules/iam"

  env           = local.env
  name_prefix   = local.name_prefix
  github_org    = var.github_org
  github_repo   = var.github_repo
  ecr_repo_arns = module.ecr.repository_arns

}

module "rds" {
  source = "../../../modules/rds"

  name_prefix          = local.name_prefix
  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.db_subnet_group_name

  eks_node_security_group_id = module.eks.app_security_group_id
  bastion_security_group_id  = null

  instance_class          = var.rds_instance_class
  multi_az                = false
  create_read_replica     = false
  deletion_protection     = false
  skip_final_snapshot     = true
  backup_retention_period = var.rds_backup_retention
  max_allocated_storage   = var.rds_max_storage
}

module "bastion" {
  source = "../../../modules/bastion"

  env               = local.env
  enabled           = false
  vpc_id            = module.vpc.vpc_id
  private_subnet_id = module.vpc.private_subnet_ids[0]
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
  num_cache_clusters         = 1
  automatic_failover_enabled = false
  multi_az_enabled           = false
}

module "secrets" {
  source = "../../../modules/secrets"

  name_prefix      = local.name_prefix
  env              = local.env
  secret_base_path = "team4/taskfarm"
  secret_names     = ["gemini-api-key"]
}

# route53: dev는 zone 생성 안 함(prod 소유). 참조만.
# prod infra가 먼저 apply돼서 zone이 있어야 dev가 참조 가능.
module "route53" {
  source = "../../../modules/route53"

  name_prefix = local.name_prefix
  domain_name = "taskfarm.site"
  create_zone = false # dev는 참조만
}

# dev는 s3 정적버킷 없음(CloudFront prod만). 필요 시 추가.
