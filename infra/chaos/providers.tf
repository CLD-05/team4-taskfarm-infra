provider "aws" {
  region = "ap-northeast-2"
  default_tags {
    tags = {
      Team  = "team4"
      env   = "prod" # 카오스 대상이 prod
      layer = "chaos"
    }
  }
}
