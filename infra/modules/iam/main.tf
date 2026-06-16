# modules/iam/main.tf

# ----------------------------------------------------------------------
# GitHub Actions OIDC (CI/CD)
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
        Resource = var.ecr_repo_arns # 특정 ECR 레포만 — 최소권한
      }
    ]
  })
}

# ----------------------------------------------------------------------
# [ADD-1] IRSA Role — dev(Fargate) addon용
# ----------------------------------------------------------------------
# IRSA는 OIDC federation 기반. trust에 "이 EKS의 이 ServiceAccount만" 넣어야 함.
# → Pod Identity와 달리 namespace:serviceaccount를 trust policy에 직접 명시.
#   (이 차이가 면접 포인트: IRSA=trust에 SA 박음 / Pod Identity=association으로 분리)
#
# var.eks_oidc_provider_arn / var.eks_oidc_provider_url 은 eks 모듈 output에서 주입.
# var.irsa_roles 가 비어있으면(prod) 아무것도 안 만듦.
resource "aws_iam_role" "irsa" {
  for_each = var.irsa_roles

  name = "${var.name_prefix}-irsa-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.eks_oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          # aud 고정
          "${var.eks_oidc_provider_url}:aud" = "sts.amazonaws.com"
          # 이 namespace의 이 ServiceAccount만 이 role 사용 가능
          "${var.eks_oidc_provider_url}:sub" = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
        }
      }
    }]
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-irsa-${each.key}" })
}

resource "aws_iam_role_policy_attachment" "irsa" {
  for_each = var.irsa_roles

  role       = aws_iam_role.irsa[each.key].name
  policy_arn = each.value.policy_arn
}

# ----------------------------------------------------------------------
# [ADD-2] Pod Identity Role — prod(node) addon/앱용 (팀원 코드 유지)
# ----------------------------------------------------------------------
# Pod Identity는 trust에 SA 넣지 않음. Principal = Service(pods.eks.amazonaws.com).
# 실제 SA 연결은 eks 모듈의 aws_eks_pod_identity_association에서.
# var.pod_identity_roles 비어있으면(dev) 아무것도 안 만듦.
resource "aws_iam_role" "pod_identity" {
  for_each = var.pod_identity_roles

  name = "${var.name_prefix}-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" } # Federated 아님!
      Action    = ["sts:AssumeRole", "sts:TagSession"]   # TagSession 필수
    }]
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-${each.key}" })
}

resource "aws_iam_role_policy_attachment" "pod_identity" {
  for_each   = var.pod_identity_roles
  role       = aws_iam_role.pod_identity[each.key].name
  policy_arn = each.value
}
