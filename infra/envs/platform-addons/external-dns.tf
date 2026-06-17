locals {
  external_dns_namespace       = "external-dns"
  external_dns_service_account = "external-dns"
  external_dns_policy          = "upsert-only"
  route53_hosted_zone_arn      = var.env == "prod" ? "arn:aws:route53:::hostedzone/${var.route53_hosted_zone_id}" : null
}

resource "aws_iam_role" "external_dns" {
  count = var.env == "prod" ? 1 : 0

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
  count = var.env == "prod" ? 1 : 0

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
          "route53:ListTagsForResources"
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
  count = var.env == "prod" ? 1 : 0

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
