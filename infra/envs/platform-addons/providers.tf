locals {
  cluster_name     = data.terraform_remote_state.infra.outputs.cluster_name
  cluster_endpoint = data.terraform_remote_state.infra.outputs.cluster_endpoint
  cluster_ca       = data.terraform_remote_state.infra.outputs.cluster_ca
}

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      team  = "team4"
      env   = var.env
      layer = "platform-addons"
    }
  }
}

provider "kubernetes" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster_ca)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", "ap-northeast-2"]
  }
}

provider "helm" {
  kubernetes {
    host                   = local.cluster_endpoint
    cluster_ca_certificate = base64decode(local.cluster_ca)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name, "--region", "ap-northeast-2"]
    }
  }
}
