# modules/secrets/versions.tf
# [ADD] versions.tf 추가 (버전 고정).

terraform {
  required_version = "~> 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
