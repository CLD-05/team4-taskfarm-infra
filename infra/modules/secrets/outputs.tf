# modules/secrets/outputs.tf

output "secret_arns" {
  description = "secret 이름 => ARN 맵. ESO IAM 정책(Secrets Manager 읽기)에 사용."
  value       = { for name, secret in aws_secretsmanager_secret.this : name => secret.arn }
}

output "secret_names" {
  description = "secret 이름 => 전체 경로 맵 (/base/env/name)."
  value       = { for name, secret in aws_secretsmanager_secret.this : name => secret.name }
}

output "kms_key_arn" {
  description = "Secrets Manager 암호화 KMS 키 ARN. ESO 정책에 kms:Decrypt 허용 시 사용."
  value       = aws_kms_key.secrets.arn
}
