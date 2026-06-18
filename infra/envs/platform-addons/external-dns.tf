# platform-addons/external-dns.tf

locals {
  external_dns_namespace       = "external-dns"
  external_dns_service_account = "external-dns"
  external_dns_policy          = "upsert-only"

  # [변경 이유] 기존: var.env == "prod" 하드코딩.
  #   ExternalDNS는 route53 hosted zone이 있어야 의미가 있고, 현재 dev는
  #   환경분리로 도메인이 없어 prod만 설치하는 게 맞음. 다만 다른 addon들(monitoring 등)과
  #   분기 방식을 enable 플래그로 통일해, "dev에 도메인을 붙이는" 상황이 생기면
  #   코드 수정 없이 tfvars로 켤 수 있게 함. null이면 기존처럼 prod만 설치.
  external_dns_enabled = var.enable_external_dns != null ? var.enable_external_dns : (var.env == "prod")

  route53_hosted_zone_arn = local.external_dns_enabled ? "arn:aws:route53:::hostedzone/${var.route53_hosted_zone_id}" : null
}

resource "aws_iam_role" "external_dns" {
  count = local.external_dns_enabled ? 1 : 0

  name = "${local.name_prefix}-external-dns"

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
          "${local.oidc_provider_url}:sub" = "system:serviceaccount:${local.external_dns_namespace}:${local.external_dns_service_account}"
        }
      }
    }]
  })

  tags = {
    Name = "${local.name_prefix}-external-dns"
  }
}

resource "aws_iam_role_policy" "external_dns" {
  count = local.external_dns_enabled ? 1 : 0

  name = "${local.name_prefix}-external-dns"
  role = aws_iam_role.external_dns[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
          # [변경 이유] 기존 "route53:ListTagsForResources"(복수형)는 존재하지 않는 액션명.
          #   올바른 액션은 단수형 "route53:ListTagsForResource". 오타로 두면 권한이
          #   실제로 부여되지 않아 ExternalDNS가 태그 조회 시 AccessDenied 가능.
          "route53:ListTagsForResource"
        ]
        Resource = local.route53_hosted_zone_arn
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "helm_release" "external_dns" {
  count = local.external_dns_enabled ? 1 : 0

  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = var.chart_versions.external_dns
  namespace        = local.external_dns_namespace
  create_namespace = true

  values = [
    yamlencode({
      provider = {
        name = "aws"
      }
      policy        = local.external_dns_policy
      domainFilters = var.external_dns_domain_filters
      txtOwnerId    = local.cluster_name

      serviceAccount = {
        create = true
        name   = local.external_dns_service_account
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns[0].arn
        }
      }
    })
  ]

  depends_on = [aws_iam_role_policy.external_dns]
}
