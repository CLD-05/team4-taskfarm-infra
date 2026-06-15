output "secret_arns" {
  description = "Secrets Manager secret ARNs by secret name."
  value = {
    for name, secret in aws_secretsmanager_secret.this :
    name => secret.arn
  }
}

output "secret_names" {
  description = "Secrets Manager secret full names by secret name."
  value = {
    for name, secret in aws_secretsmanager_secret.this :
    name => secret.name
  }
}

output "kms_key_arn" {
  description = "KMS key ARN used for Secrets Manager encryption."
  value       = aws_kms_key.secrets.arn
}
