# envs/prod/infra/main.tf

locals {
  env         = "prod"
  name_prefix = "team4-prod"
}

module "vpc" {
  source = "../../../modules/vpc"

  env                  = local.env
  name_prefix          = local.name_prefix
  azs                  = var.azs # [2a, 2c] 이중
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  db_subnet_cidrs      = var.db_subnet_cidrs
}

# EKS — node group. service role·SG 내부 생성.
module "eks" {
  source = "../../../modules/eks"

  name_prefix         = local.name_prefix
  eks_cluster_version = var.eks_cluster_version
  compute_type        = "node_group"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  endpoint_public_access  = false # prod: private only
  endpoint_private_access = true
  public_access_cidrs     = []

  # node group 설정 (prod)
  node_group_instance_types = var.node_group_instance_types
  node_group_desired_size   = var.node_group_desired_size
  node_group_min_size       = var.node_group_min_size
  node_group_max_size       = var.node_group_max_size
  node_group_disk_size      = var.node_group_disk_size

  admin_iam_role_arn = var.admin_iam_role_arn
  namespace          = var.app_namespace

  # prod: EBS CSI용 IRSA (managed addon은 IRSA만) — iam 모듈에서 받음
  ebs_csi_irsa_role_arn = try(module.iam.irsa_role_arns["ebs-csi"], null)

  enable_pod_identity_s3 = false # 앱이 S3 직접 안 씀
  addon_versions         = var.addon_versions
}

# IAM — GitHub OIDC + prod addon Pod Identity + EBS CSI IRSA.
module "iam" {
  source = "../../../modules/iam"

  env           = local.env
  name_prefix   = local.name_prefix
  github_org    = var.github_org
  github_repo   = var.github_repo
  ecr_repo_arns = var.ecr_repo_arns

  eks_oidc_provider_arn = module.eks.oidc_provider_arn
  eks_oidc_provider_url = module.eks.oidc_provider_url

  # prod addon = Pod Identity. (단 EBS CSI는 managed addon이라 IRSA — irsa_roles에)
  pod_identity_roles = var.pod_identity_roles
  irsa_roles         = var.irsa_roles # 보통 ebs-csi만
}

# RDS — Multi-AZ + Read Replica.
module "rds" {
  source = "../../../modules/rds"

  name_prefix          = local.name_prefix
  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.db_subnet_group_name

  eks_node_security_group_id = module.eks.app_security_group_id
  bastion_security_group_id  = module.bastion.security_group_id # prod bastion 있음

  instance_class              = var.rds_instance_class
  read_replica_instance_class = var.rds_replica_instance_class
  multi_az                    = true
  create_read_replica         = true
  deletion_protection         = true
  skip_final_snapshot         = false
  backup_retention_period     = var.rds_backup_retention # 7+
  max_allocated_storage       = var.rds_max_storage
}

# Bastion — prod 진입점(endpoint private).
module "bastion" {
  source = "../../../modules/bastion"

  env               = local.env
  enabled           = true
  vpc_id            = module.vpc.vpc_id
  private_subnet_id = module.vpc.private_subnet_ids[0]
}
