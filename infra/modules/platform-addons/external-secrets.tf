# platform-addons/external-secrets.tf

# [참고] ESO(External Secrets Operator)는 dev/prod 모두 필요(분기 없음).
#   dev도 앱이 JWT_SECRET·DB 비밀 등을 Secrets Manager에서 받아야 하므로 항상 설치.
#   (monitoring과 달리 "끄는" 시나리오가 없어 enable 플래그를 두지 않음)
locals {
  external_secrets_namespace       = "external-secrets"
  external_secrets_service_account = "external-secrets"
}

resource "aws_iam_role" "external_secrets" {
  name                 = "${local.name_prefix}-external-secrets"
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
          "${local.oidc_provider_url}:sub" = "system:serviceaccount:${local.external_secrets_namespace}:${local.external_secrets_service_account}"
        }
      }
    }]
  })

  tags = {
    Name = "${local.name_prefix}-external-secrets"
  }
}

resource "aws_iam_role_policy" "external_secrets" {
  name = "${local.name_prefix}-external-secrets"
  role = aws_iam_role.external_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = var.external_secrets_secret_arns
    }]
  })
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.chart_versions.external_secrets
  namespace        = local.external_secrets_namespace
  create_namespace = true

  # 차트가 CRD(v1 포함)를 설치/관리
  set {
    name  = "installCRDs"
    value = "true"
  }

  # [FARGATE-FIX] webhook 포트를 9443으로 — Fargate kubelet(10250)과 충돌 회피
  set {
    name  = "webhook.port"
    value = "9443"
  }

  wait    = true
  timeout = 600

  values = [
    yamlencode({
      serviceAccount = {
        create = true
        name   = local.external_secrets_service_account
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.external_secrets.arn
        }
      }
    })
  ]

  depends_on = [
    aws_iam_role_policy.external_secrets,
    helm_release.alb_controller,
  ]
}
