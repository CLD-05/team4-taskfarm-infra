# envs/dev/infra/backend.tf

terraform {
  backend "s3" {
    bucket       = "tfstate-lionkdt5-team4"
    key          = "dev/infra/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
