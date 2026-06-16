# modules/iam/main.tf

# ----------------------------------------------------------------------
# GitHub Actions OIDC (CI/CD) — 팀원 코드 유지
# ----------------------------------------------------------------------
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
  github_oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

resource "aws_iam_role" "github_actions" {
  name = "${var.name_prefix}-gha-role"

  # trust policy = "누가 이 역할을 빌리나"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.github_oidc_provider_arn }
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

  # [FIX-1] var.tags 반영 (다른 리소스와 일관성)
  tags = merge(var.tags, { Name = "${var.name_prefix}-gha-role" })
}

resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "${var.name_prefix}-gha-ecr"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({ # assume_role_policy 아님! "policy"
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*" # docker login용, 전역 예외 (이건 * 가 맞음)
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
