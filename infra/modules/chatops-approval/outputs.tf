output "api_endpoint" {
  description = "Base URL for the Slack ChatOps approval API."
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "slack_command_request_url" {
  description = "Slack slash command Request URL."
  value       = "${aws_apigatewayv2_api.this.api_endpoint}/slack/commands"
}

output "slack_interactivity_request_url" {
  description = "Slack Interactivity Request URL."
  value       = "${aws_apigatewayv2_api.this.api_endpoint}/slack/actions"
}

output "lambda_function_name" {
  description = "ChatOps approval Lambda function name."
  value       = aws_lambda_function.this.function_name
}
