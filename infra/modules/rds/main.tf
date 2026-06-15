locals {
  resource_prefix = lower(replace(var.name_prefix, "_", "-"))
}

resource "aws_security_group" "rds" {
  name        = "${local.resource_prefix}-rds-sg"
  description = "Allow MySQL access from EKS node security group only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from EKS nodes"
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
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

resource "aws_db_subnet_group" "this" {
  name        = "${local.resource_prefix}-db-subnet-group"
  description = "DB subnet group for ${local.resource_prefix} RDS"
  subnet_ids  = var.db_subnet_ids

  tags = merge(var.tags, {
    Name = "${local.resource_prefix}-db-subnet-group"
  })
}

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

  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.rds.key_id

  db_subnet_group_name   = aws_db_subnet_group.this.name
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

  backup_retention_period = 0
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = true

  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  tags = merge(var.tags, {
    Name = "${local.resource_prefix}-mysql-reader"
  })
}
