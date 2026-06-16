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
  public_subnet_cidrs  = var.public_subnet_cidrs  # 2개(2a,2c) — ALB 2AZ 요구
  private_subnet_cidrs = var.private_subnet_cidrs # /20
  db_subnet_cidrs      = var.db_subnet_cidrs
}

# EKS — Fargate. service role·SG는 모듈 내부 생성(외부 주입 없음).
module "eks" {
  source = "../../../modules/eks"

  name_prefix         = local.name_prefix
  eks_cluster_version = var.eks_cluster_version
  compute_type        = "fargate"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  endpoint_public_access  = true # dev: 로컬 kubectl
  endpoint_private_access = true
  public_access_cidrs     = var.public_access_cidrs

  admin_iam_role_arn = var.admin_iam_role_arn
  namespace          = var.app_namespace

  enable_pod_identity_s3 = false # dev Fargate
  addon_versions         = var.addon_versions
}

# IAM — GitHub OIDC + dev addon IRSA (Fargate라 Pod Identity 대신).
module "iam" {
  source = "../../../modules/iam"

  env           = local.env
  name_prefix   = local.name_prefix
  github_org    = var.github_org
  github_repo   = var.github_repo
  ecr_repo_arns = var.ecr_repo_arns # TODO: module.ecr.repo_arns

  eks_oidc_provider_arn = module.eks.oidc_provider_arn
  eks_oidc_provider_url = module.eks.oidc_provider_url
  irsa_roles            = var.irsa_roles # addon 정책 만든 뒤 채움

  pod_identity_roles = {} # dev는 IRSA만
}

# RDS — Single-AZ, replica 없음.
module "rds" {
  source = "../../../modules/rds"

  name_prefix          = local.name_prefix
  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.db_subnet_group_name

  eks_node_security_group_id = module.eks.app_security_group_id
  bastion_security_group_id  = null # dev bastion 없음

  instance_class          = var.rds_instance_class
  multi_az                = false
  create_read_replica     = false
  deletion_protection     = false
  skip_final_snapshot     = true
  backup_retention_period = var.rds_backup_retention
  max_allocated_storage   = var.rds_max_storage
}

# Bastion — dev 불필요(endpoint public).
module "bastion" {
  source = "../../../modules/bastion"

  env               = local.env
  enabled           = false
  vpc_id            = module.vpc.vpc_id
  private_subnet_id = module.vpc.private_subnet_ids[0]
}
