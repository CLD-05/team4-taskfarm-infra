# modules/vpc/versions.tf
# 리팩토링 노트:
#   [FIX] >= 1.5 / >= 5.0 → ~> 1.14 / ~> 5.0 으로 변경.
#   이유: ">=" 는 미래 버전(2.x, 6.x 등)까지 열려 있어 어느 날 provider가
#         메이저 업데이트되면 plan/apply가 갑자기 깨질 수 있음(재현성 X).
#         "~>" 로 마이너 범위만 허용해 버전 고정 — 팀 결정 사항.

terraform {
  required_version = "~> 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
