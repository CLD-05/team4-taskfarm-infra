# =====================================================================
# [담당 A] metrics-server
# =====================================================================
# 역할: 리소스 메트릭 수집(CPU/메모리). HPA가 이거 없으면 동작 안 함.
# 방식: helm_release (IRSA 불필요 — 클러스터 내부 메트릭만)
#
# 구현 체크리스트:
#  [ ] helm_release "metrics-server"
#      - repository: https://kubernetes-sigs.github.io/metrics-server/
#      - chart: metrics-server
#      - version: var.chart_versions.metrics_server (고정!)
#      - namespace: kube-system
#
# ⚠️ HPA(앱 오토스케일)가 이거에 의존. 간단하지만 빠지면 HPA가 조용히 안 됨.
# ⚠️ EKS에 따라 kubelet TLS 이슈로 --kubelet-insecure-tls 필요할 수 있음(args set).

# resource "helm_release" "metrics_server" { ... }
