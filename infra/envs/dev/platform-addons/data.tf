# envs/dev/platform-addons/data.tf
data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = "tfstate-lionkdt5-team4"
    key    = "dev/infra/terraform.tfstate"
    region = "ap-northeast-2"
  }
}
