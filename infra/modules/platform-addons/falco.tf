resource "helm_release" "falco" {
  count = local.monitoring_enabled ? 1 : 0

  name             = "falco"
  repository       = "https://falcosecurity.github.io/charts"
  chart            = "falco"
  version          = var.chart_versions.falco
  namespace        = "falco"
  create_namespace = true

  values = [
    yamlencode({
      driver  = { kind = "modern_ebpf" }
      metrics = { enabled = true }
      serviceMonitor = {
        create = true
        labels = { release = "kube-prometheus-stack" }
      }
      falcosidekick = {
        enabled = true
        webui   = { enabled = true }
      }
    })
  ]
}
