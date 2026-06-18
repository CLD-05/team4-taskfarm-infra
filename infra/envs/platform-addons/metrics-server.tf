# platform-addons/metrics-server.tf

# [참고] metrics-server는 dev/prod 모두 필요(분기 없음).
#   HPA·KEDA·kubectl top 등이 이 메트릭에 의존하므로 사실상 필수. enable 플래그 불필요.
# [참고] Fargate(dev)에서도 metrics-server는 동작하나, kubelet 보안포트 접근 방식에 따라
#   --kubelet-insecure-tls 등의 args가 필요할 수 있음. dev에서 'kubectl top'이 안 되면
#   args(kubelet-preferred-address-types, insecure-tls)를 set으로 추가해 확인할 것.
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.chart_versions.metrics_server
  namespace  = "kube-system"
}
