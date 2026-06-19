terraform {
  backend "s3" {
    bucket       = "tfstate-lionkdt5-team4"
    key          = "dev/platform-addons/terraform.tfstate"
    region       = "ap-northeast-2"
    use_lockfile = true
  }
}
