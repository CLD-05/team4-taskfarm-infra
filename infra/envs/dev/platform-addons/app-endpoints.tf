resource "kubernetes_config_map" "taskfarm_endpoints" {
  metadata {
    name      = "taskfarm-endpoints"
    namespace = "taskfarm-dev"
  }
  data = {
    DB_HOST    = split(":", data.terraform_remote_state.infra.outputs.rds_primary_endpoint)[0]
    REDIS_HOST = data.terraform_remote_state.infra.outputs.redis_primary_endpoint
  }
}
