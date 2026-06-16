# modules/rds/versions.tf
# [ADD] versions.tf가 없어서 추가 (버전 고정 — 팀 결정).

terraform {
  required_version = "~> 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
