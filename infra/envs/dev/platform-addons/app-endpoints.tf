resource "kubernetes_namespace" "taskfarm_dev" {
  metadata {
    name = "taskfarm-dev"
  }
}

resource "kubernetes_config_map" "taskfarm_endpoints" {
  metadata {
    name      = "taskfarm-endpoints"
    namespace = kubernetes_namespace.taskfarm_dev.metadata[0].name
  }
  data = {
    DB_HOST    = split(":", data.terraform_remote_state.infra.outputs.rds_primary_endpoint)[0]
    REDIS_HOST = data.terraform_remote_state.infra.outputs.redis_primary_endpoint
  }
}
