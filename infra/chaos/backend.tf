terraform {
  backend "s3" {
    bucket       = "tfstate-lionkdt5-team4"
    key          = "chaos/terraform.tfstate" # ← chaos 전용 state 경로
    region       = "ap-northeast-2"
    use_lockfile = true
  }
}
