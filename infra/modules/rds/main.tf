# modules/rds/main.tf

locals {
  resource_prefix = lower(replace(var.name_prefix, "_", "-"))
}

resource "aws_security_group" "rds" {
  name        = "${local.resource_prefix}-rds-sg"
  description = "Allow MySQL access from EKS node SG (and bastion SG if provided)"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from EKS nodes"
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
  }

  # [FIX-2] bastion SG에서의 MySQL 접근 (운영 거점). bastion_security_group_id가
  #         null이 아닐 때만 규칙 생성 (dev에서 bastion 없으면 null → 미생성).
  dynamic "ingress" {
    for_each = var.bastion_security_group_id != null ? [1] : []
    content {
      description     = "MySQL from bastion"
      from_port       = var.port
      to_port         = var.port
      protocol        = "tcp"
      security_groups = [var.bastion_security_group_id]
    }
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${local.resource_prefix}-rds-sg"
  })
}

resource "aws_kms_key" "rds" {
  description             = "KMS key for ${local.resource_prefix} RDS encryption"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${local.resource_prefix}-rds-kms"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${local.resource_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# [FIX-1] aws_db_subnet_group 리소스 삭제 — vpc 모듈 것을 var로 받습니다.
# (원본)
# resource "aws_db_subnet_group" "this" {
#   name        = "${local.resource_prefix}-db-subnet-group"
#   description = "DB subnet group for ${local.resource_prefix} RDS"
#   subnet_ids  = var.db_subnet_ids
#   tags = merge(var.tags, { Name = "${local.resource_prefix}-db-subnet-group" })
# }

resource "aws_db_instance" "primary" {
  identifier = "${local.resource_prefix}-mysql"

  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  db_name  = var.db_name
  username = var.username
  port     = var.port

  # 비밀번호를 Secrets Manager에 위임 (tfvars에 평문 없음)
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.rds.key_id

  # [FIX-1] vpc 모듈이 만든 db subnet group 이름을 받아서 사용
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.resource_prefix}-mysql-final-snapshot"

  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  # read replica 만들려면 자동백업이 켜져 있어야 함(precondition)
  lifecycle {
    precondition {
      condition     = !var.create_read_replica || var.backup_retention_period > 0
      error_message = "backup_retention_period must be greater than 0 when create_read_replica is true."
    }
  }

  tags = merge(var.tags, {
    Name = "${local.resource_prefix}-mysql"
  })
}

resource "aws_db_instance" "read_replica" {
  count = var.create_read_replica ? 1 : 0

  identifier          = "${local.resource_prefix}-mysql-reader"
  replicate_source_db = aws_db_instance.primary.identifier

  instance_class = coalesce(var.read_replica_instance_class, var.instance_class)

  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds.id]

  # replica는 자체 백업 불필요(소스에서 복제) — 0이 맞습니다.
  backup_retention_period = 0
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = true

  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  tags = merge(var.tags, {
    Name = "${local.resource_prefix}-mysql-reader"
  })
}
