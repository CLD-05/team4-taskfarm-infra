# envs/dev/infra/providers.tf

terraform {
  required_version = "~> 1.15.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    tls = { source = "hashicorp/tls", version = "~> 4.0" }
  }
}

provider "aws" {
  region = "ap-northeast-2"
  default_tags {
    tags = {
      Team        = "team4"
      Environment = "dev"
      Project     = "taskfarm"
      ManagedBy   = "terraform"
    }
  }
}
