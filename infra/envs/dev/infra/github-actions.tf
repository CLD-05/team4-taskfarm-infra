# infra/envs/dev/infra/github-actions.tf

locals {
  github_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"

  # 이 role을 쓸 레포 (app 레포). 필요시 추가.
  github_repos = ["CLD-05/team4-taskfarm-app"]
  github_subs  = [for repo in local.github_repos : "repo:${repo}:*"]
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "github_actions" {
  name                 = "team4-github-actions"
  permissions_boundary = var.permissions_boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.github_oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        # 우리 레포에서 온 요청만 허용 (다른 팀/레포 차단)
        StringLike = {
          "token.actions.githubusercontent.com:sub" = local.github_subs
        }
      }
    }]
  })

  tags = {
    Name = "team4-github-actions"
  }
}

resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "team4-github-actions-ecr"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ECR 로그인 토큰 — 리소스 지정 불가라 *
        Sid      = "ECRAuthToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        # 이미지 push/pull — team4 레포로만 제한
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "arn:aws:ecr:ap-northeast-2:${data.aws_caller_identity.current.account_id}:repository/team4-*"
      }
    ]
  })
}

output "github_actions_role_arn" {
  description = "GitHub Secret(AWS_ROLE_ARN)에 넣을 값"
  value       = aws_iam_role.github_actions.arn
}
