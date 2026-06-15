variable "env" {
  description = "환경 식별자 (dev/prod). 리소스 이름·태그에 사용"
  type        = string
}

variable "enabled" {
  description = <<-EOT
    Bastion 생성 여부 토글.
    - dev: EKS endpoint가 public이라 로컬에서 바로 kubectl 가능 → bastion 불필요 → false 권장 (월 $7~8 절감)
    - prod: EKS endpoint가 private이라 bastion이 유일한 진입점 → true
  EOT
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "Bastion이 속할 VPC ID (vpc 모듈 output)"
  type        = string
}

variable "private_subnet_id" {
  description = "Bastion을 둘 프라이빗 서브넷 ID. SSM 접속이라 퍼블릭 불필요(SSH 미개방). vpc 모듈 output에서 주입"
  type        = string
}

variable "instance_type" {
  description = "Bastion 인스턴스 타입. 운영 도구 허브용이라 작은 사양으로 충분"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "Bastion AMI. 비우면 최신 Amazon Linux 2023(x86_64) 자동 조회. ARM 인스턴스 쓰면 arm64 AMI로 직접 지정 + user_data kubectl도 arm64로"
  type        = string
  default     = ""
}

variable "tags" {
  description = "공통 태그 (provider default_tags 외 추가분). team 태그는 default_tags에서 소문자로 주입"
  type        = map(string)
  default     = {}
}
