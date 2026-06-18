# platform-addons/backend.tf

terraform {
  backend "s3" {
    bucket       = "tfstate-lionkdt5-team4"
    region       = "ap-northeast-2"
    use_lockfile = true
    # key는 backend-{env}.hcl에서 주입
  }
}
