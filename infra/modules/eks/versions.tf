# modules/eks/versions.tf

# [ADD] eks 모듈에 versions.tf가 없어서 추가했습니다.
#   - 버전 고정(~>) — 팀 결정
#   - tls provider 추가: OIDC provider thumbprint 계산용(outputs.tf 주석 참고)

terraform {
  required_version = "~> 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
