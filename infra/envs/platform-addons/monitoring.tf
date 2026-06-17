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

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_versions.kube_prometheus
  # kube-prometheus-stack을 설치할 namespace
  namespace        = "monitoring"
  create_namespace = true

  values = [
    yamlencode({
      # Grafana 활성화
      grafana = {
        enabled = true

        # Grafana admin 계정 정보를 Kubernetes Secret에서 가져오도록 설정
        admin = {
          existingSecret = var.grafana_admin_existing_secret
          userKey        = var.grafana_admin_user_key
          passwordKey    = var.grafana_admin_password_key
        }

        # Grafana를 외부에서 접속할 수 있게 ingress 설정
        ingress = {
          enabled          = var.grafana_ingress_enabled
          ingressClassName = "alb"

          annotations = var.grafana_ingress_enabled ? {
            "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
            "alb.ingress.kubernetes.io/target-type" = "ip"
            "alb.ingress.kubernetes.io/listen-ports" = jsonencode([
              {
                HTTP = 80
              }
            ])
          } : {} # grafana_ingress_enabled가 false면 annotation을 비워둔다.

          # Grafana Ingress에 사용할 host를 설정하는 부분
          hosts = var.grafana_ingress_enabled ? [
            var.grafana_host
          ] : []
        }
      }

      prometheus = {
        prometheusSpec = {
          retention = var.prometheus_retention

          # 프로메테우스 데이터를 영구 저장소에 저장하기 위한 설정
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.prometheus_storage_class_name
                accessModes      = ["ReadWriteOnce"]

                resources = {
                  requests = {
                    storage = var.prometheus_storage_size
                  }
                }
              }
            }
          }
        }
      }
    })
  ]

  depends_on = [helm_release.alb_controller]
}

resource "helm_release" "keda" {
  # Keda 설치
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = var.chart_versions.keda
  namespace        = "keda"
  create_namespace = true
}
