# platform-addons\data.tf

data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = "tfstate-lionkdt5-team4"
    key    = "team4/${var.env}/infra/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
