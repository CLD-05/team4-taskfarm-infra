output "primary_endpoint" {
  description = "Primary RDS endpoint for application write traffic."
  value       = aws_db_instance.primary.endpoint
}

output "primary_address" {
  description = "Primary RDS hostname."
  value       = aws_db_instance.primary.address
}

output "primary_identifier" {
  description = "Primary RDS instance identifier."
  value       = aws_db_instance.primary.identifier
}

output "read_replica_endpoint" {
  description = "Read replica endpoint for read traffic. Null when create_read_replica is false."
  value       = var.create_read_replica ? aws_db_instance.read_replica[0].endpoint : null
}

output "read_replica_address" {
  description = "Read replica hostname. Null when create_read_replica is false."
  value       = var.create_read_replica ? aws_db_instance.read_replica[0].address : null
}

output "db_security_group_id" {
  description = "Security group ID attached to RDS."
  value       = aws_security_group.rds.id
}

output "db_subnet_group_name" {
  description = "DB subnet group name used by RDS."
  value       = aws_db_subnet_group.this.name
}

output "db_name" {
  description = "Initial database name."
  value       = var.db_name
}

output "port" {
  description = "MySQL port."
  value       = var.port
}

output "kms_key_arn" {
  description = "KMS key ARN used for RDS storage encryption."
  value       = aws_kms_key.rds.arn
}

output "master_user_secret_arn" {
  description = "Secrets Manager secret ARN managed by RDS for the master user password."
  value       = aws_db_instance.primary.master_user_secret[0].secret_arn
  sensitive   = true
}
