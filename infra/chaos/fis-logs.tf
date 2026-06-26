resource "aws_cloudwatch_log_group" "fis" {
  name              = "/team4/chaos/fis"
  retention_in_days = 14
}

resource "aws_iam_role_policy" "fis_logs" {
  name = "fis-logs"
  role = aws_iam_role.fis.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogDelivery",
        "logs:GetLogDelivery",
        "logs:UpdateLogDelivery",
        "logs:DeleteLogDelivery",
        "logs:ListLogDeliveries",
        "logs:PutResourcePolicy",        # ← 핵심 (FIS가 로그그룹에 정책 설정)
        "logs:DescribeResourcePolicies", # ← 핵심
        "logs:DescribeLogGroups",
        "logs:PutLogEvents",
        "logs:CreateLogStream"
      ]
      Resource = "*"
    }]
  })
}
