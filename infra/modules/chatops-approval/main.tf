locals {
  resource_prefix = lower(replace(var.name_prefix, "_", "-"))
  function_name   = "${local.resource_prefix}-chatops-approval"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.js"
  output_path = "${path.root}/.terraform/${local.function_name}.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 14

  tags = merge(var.tags, {
    Name = "${local.function_name}-logs"
  })
}

resource "aws_iam_role" "lambda" {
  name                 = "${local.function_name}-role"
  permissions_boundary = var.permissions_boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name = "${local.function_name}-role"
  })
}

resource "aws_iam_role_policy" "lambda" {
  name = "${local.function_name}-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
        },
        {
          Effect = "Allow"
          Action = [
            "secretsmanager:GetSecretValue"
          ]
          Resource = [
            var.github_token_secret_arn,
            var.slack_signing_secret_arn
          ]
        }
      ],
      var.secret_kms_key_arn == null ? [] : [
        {
          Effect = "Allow"
          Action = [
            "kms:Decrypt"
          ]
          Resource = var.secret_kms_key_arn
        }
      ]
    )
  })
}

resource "aws_lambda_function" "this" {
  function_name    = local.function_name
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      ALLOWED_SLACK_USER_IDS   = join(",", var.allowed_slack_user_ids)
      GITHUB_OWNER             = var.github_owner
      GITHUB_REPO              = var.github_repo
      GITHUB_REF               = var.github_ref
      GITHUB_TOKEN_SECRET_ID   = var.github_token_secret_name
      GITHUB_WORKFLOW_ID       = var.github_workflow_id
      SLACK_SIGNING_SECRET_ID  = var.slack_signing_secret_name
      WORKFLOW_PROD_INPUT_NAME = "prod"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.lambda
  ]

  tags = merge(var.tags, {
    Name = local.function_name
  })
}

resource "aws_apigatewayv2_api" "this" {
  name          = "${local.function_name}-api"
  protocol_type = "HTTP"

  tags = merge(var.tags, {
    Name = "${local.function_name}-api"
  })
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  tags = merge(var.tags, {
    Name = "${local.function_name}-default-stage"
  })
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.this.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "commands" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /slack/commands"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "actions" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /slack/actions"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
