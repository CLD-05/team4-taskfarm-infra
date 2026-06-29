locals {
  admin_app_namespace       = "taskfarm-${var.env}"
  admin_app_service_account = "taskfarm-admin-sa"
}

resource "aws_iam_role" "admin_mfa" {
  name                 = "${local.name_prefix}-admin-mfa"
  permissions_boundary = var.permissions_boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
          "${local.oidc_provider_url}:sub" = "system:serviceaccount:${local.admin_app_namespace}:${local.admin_app_service_account}"
        }
      }
    }]
  })

  tags = {
    Name = "${local.name_prefix}-admin-mfa"
  }
}

resource "aws_iam_role_policy" "admin_mfa" {
  name = "${local.name_prefix}-admin-mfa"
  role = aws_iam_role.admin_mfa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.mfa_kms_key_arn
      }
    ]
  })
}

output "admin_mfa_role_arn" {
  description = "taskfarm-admin-sa 에 달 IRSA Role ARN"
  value       = aws_iam_role.admin_mfa.arn
}
