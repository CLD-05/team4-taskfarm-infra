resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.chart_versions.metrics_server
  namespace  = "kube-system"

  # Fargate(dev) kubelet 인증서가 127.0.0.1용이라 IP 검증 실패 → 검증 스킵
  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
}
