locals {
  resource_prefix  = lower(replace(var.name_prefix, "_", "-"))
  secret_base_path = trim(var.secret_base_path, "/")
}

resource "aws_kms_key" "secrets" {
  description             = "KMS key for ${local.resource_prefix} Secrets Manager"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${local.resource_prefix}-secrets-kms"
  })
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${local.resource_prefix}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_secretsmanager_secret" "this" {
  for_each = toset(var.secret_names)

  name                    = "/${local.secret_base_path}/${var.env}/${each.value}"
  description             = "Secret for ${local.resource_prefix} ${each.value}"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = var.env == "dev" ? 0 : var.recovery_window_in_days

  tags = merge(var.tags, {
    Name = "${local.resource_prefix}-${each.value}"
  })
}