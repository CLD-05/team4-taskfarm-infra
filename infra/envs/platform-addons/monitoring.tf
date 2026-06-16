# =====================================================================
# [담당 D] kube-prometheus-stack + KEDA
# =====================================================================
# 역할:
#   - kube-prometheus-stack: Prometheus + Grafana + Alertmanager (관측)
#   - KEDA: 이벤트 기반 오토스케일 (Redis 큐 기반 워커 스케일 — 이 앱 AI 추천 워커)
# 방식: helm_release 2개. KEDA는 IRSA 필요할 수 있음(CloudWatch 등 외부 트리거 시).
#
# 구현 체크리스트 — kube-prometheus-stack:
#  [ ] helm_release "kube-prometheus-stack"
#      - repository: https://prometheus-community.github.io/helm-charts
#      - chart: kube-prometheus-stack
#      - version: var.chart_versions.kube_prometheus (고정!)
#      - namespace: monitoring (create_namespace=true)
#      - values: grafana.ingress (ALB) — ⚠️ ALB Controller(A) 먼저
#      - prometheus 보존기간·스토리지(EBS PV) 설정
#      - grafana adminPassword — ⚠️ 평문 금지. secret 참조 또는 ESO 연동.
#
# 구현 체크리스트 — KEDA:
#  [ ] helm_release "keda"
#      - repository: https://kedacore.github.io/charts
#      - chart: keda
#      - version: var.chart_versions.keda (고정!)
#      - namespace: keda (create_namespace=true)
#  [ ] (앱 레포 or config) ScaledObject — Redis 큐 길이 트리거로 워커 스케일.
#      ※ ScaledObject 매니페스트는 config 레포에서 관리 권장. 여기선 KEDA 설치까지.
#
# ⚠️ Grafana ingress → ALB Controller(A) 의존. depends_on.
# ⚠️ Prometheus 스토리지: EBS CSI driver 필요 (EKS Add-on 6종 중 하나 — infra/eks에서 설치 확인).
# ⚠️ adminPassword 등 시크릿 평문 커밋 금지.

# resource "helm_release" "kube_prometheus_stack" { ... }
# resource "helm_release" "keda" { ... }
