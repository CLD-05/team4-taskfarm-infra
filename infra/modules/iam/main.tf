data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # 하드코딩 대신 동적 조회 (인증서 갱신돼도 안 깨짐)
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = merge(var.tags, { Name = "${var.name_prefix}-github-oidc" })
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

resource "aws_iam_role" "github_actions" {
  name = "${var.name_prefix}-gha-role"

  # trust policy = "누가 이 역할을 빌리나"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn } # STEP2의 그 ARN
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        # aud는 정확히 일치 (고정값)
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        # sub는 우리 레포/브랜치만 (패턴 매칭)
        StringLike = {
          "token.actions.githubusercontent.com:sub" = var.env == "prod" ? "repo:${var.github_org}/${var.github_repo}:environment:prod" : "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
        }
      }
    }]
  })

  tags = { Name = "${var.name_prefix}-gha-role" }
}

resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "${var.name_prefix}-gha-ecr"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({ # ← assume_role_policy 아님! "policy"
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*" # docker login용, 전역 예외
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = var.ecr_repo_arns # 특정 ECR 레포만
      }
    ]
  })
}

resource "aws_iam_role" "pod_identity" {
  for_each = var.pod_identity_roles

  name = "${var.name_prefix}-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" } # ← Federated 아님!
      Action    = ["sts:AssumeRole", "sts:TagSession"]   # TagSession 필수
    }]
  })

  tags = { Name = "${var.name_prefix}-${each.key}" }
}

resource "aws_iam_role_policy_attachment" "pod_identity" {
  for_each   = var.pod_identity_roles
  role       = aws_iam_role.pod_identity[each.key].name
  policy_arn = each.value
}
