# modules/bastion/outputs.tf

output "instance_id" {
  description = "Bastion 인스턴스 ID. SSM 접속: aws ssm start-session --target <이 값>. 미생성 시 null"
  value       = try(aws_instance.this[0].id, null)
}

output "security_group_id" {
  description = "Bastion 보안그룹 ID. rds 모듈에서 이 SG를 인바운드(3306) source로 추가해 mysql 접근 허용. 미생성 시 null"
  value       = try(aws_security_group.this[0].id, null)
}

output "iam_role_arn" {
  description = "Bastion IAM 역할 ARN. eks 모듈에서 aws_eks_access_entry로 등록해 kubectl 권한 부여. 미생성 시 null"
  value       = try(aws_iam_role.this[0].arn, null)
}

output "private_ip" {
  description = "Bastion 프라이빗 IP (참고용. 접속은 SSM으로). 미생성 시 null"
  value       = try(aws_instance.this[0].private_ip, null)
}
