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
      Action = ["logs:CreateLogDelivery", "logs:PutLogEvents",
      "logs:CreateLogStream", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
      Resource = "*"
    }]
  })
}
