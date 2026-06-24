resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.chart_versions.metrics_server
  namespace  = "kube-system"

  # defaultArgs 통째로 재정의 (secure-port를 10251로, Fargate kubelet 10250과 분리)
  set {
    name  = "defaultArgs[0]"
    value = "--cert-dir=/tmp"
  }
  set {
    name  = "defaultArgs[1]"
    value = "--kubelet-preferred-address-types=InternalIP\\,ExternalIP\\,Hostname"
  }
  set {
    name  = "defaultArgs[2]"
    value = "--kubelet-use-node-status-port"
  }
  set {
    name  = "defaultArgs[3]"
    value = "--metric-resolution=15s"
  }
  set {
    name  = "defaultArgs[4]"
    value = "--kubelet-insecure-tls"
  }
  set {
    name  = "defaultArgs[5]"
    value = var.env == "dev" ? "--secure-port=10251" : "--secure-port=10250"
  }
  set {
    name  = "containerPort"
    value = var.env == "dev" ? "10251" : "10250"
  }

}
