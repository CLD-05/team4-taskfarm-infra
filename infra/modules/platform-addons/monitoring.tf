# platform-addons/monitoring.tf

locals {
  # [변경 이유] 기존: monitoring_enabled = var.env == "prod" (env에 하드코딩).
  #   → dev에 모니터링을 켜고 싶어도 코드를 고쳐야만 했음.
  #   enable_monitoring 플래그로 분리. null이면 기존처럼 prod만 켜지고(기본 동작 보존),
  #   dev tfvars에서 enable_monitoring=true를 주면 dev에서도 켤 수 있음.
  monitoring_enabled = var.enable_monitoring != null ? var.enable_monitoring : (var.env == "prod")

  # [추가 이유] Prometheus 영구 스토리지(EBS PV)는 노드그룹(prod)에서만 가능.
  #   dev는 Fargate라 EBS 볼륨 마운트가 불가하고 EBS CSI driver도 없음(prod 노드 전용).
  #   따라서 dev에 모니터링을 켜더라도 EBS PV는 쓸 수 없어, 스토리지 사용 여부를 분리.
  #   prod=EBS PV(영구), dev=emptyDir(임시, 파드 재시작 시 소실되지만 Fargate에서 동작).
  monitoring_use_ebs = var.env == "prod"

  # [추가 이유] KEDA는 모니터링과 분리(생명주기 다름). enable_keda 플래그로 제어.
  keda_enabled = var.enable_keda
}

resource "helm_release" "kube_prometheus_stack" {
  count = local.monitoring_enabled ? 1 : 0

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_versions.kube_prometheus

  namespace        = "monitoring"
  create_namespace = true

  values = [
    yamlencode({
      grafana = {
        enabled = true

        admin = {
          existingSecret = var.grafana_admin_existing_secret
          userKey        = var.grafana_admin_user_key
          passwordKey    = var.grafana_admin_password_key
        }

        ingress = {
          enabled          = var.grafana_ingress_enabled
          ingressClassName = "alb"

          annotations = var.grafana_ingress_enabled ? {
            "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
            "alb.ingress.kubernetes.io/target-type" = "ip"
            "alb.ingress.kubernetes.io/listen-ports" = jsonencode([
              { HTTP = 80 },
              { HTTPS = 443 }
            ])
            "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
            "alb.ingress.kubernetes.io/certificate-arn" = "arn:aws:acm:ap-northeast-2:194722398200:certificate/7088d446-8124-4476-9b87-e88b978a3924"
          } : {}

          hosts = var.grafana_ingress_enabled ? [
            var.grafana_host
          ] : []
        }
      }

      prometheus = {
        prometheusSpec = merge(
          {
            retention = var.prometheus_retention
          },
          # [변경 이유] 기존: storageSpec(EBS PV)를 무조건 설정 →
          #   dev(Fargate)에 모니터링을 켜면 EBS 마운트 불가로 Prometheus 파드가
          #   Pending에 빠져 뜨지 않음. EBS를 쓸 수 있는 prod에서만 storageSpec을 주고,
          #   dev는 storageSpec을 비워 emptyDir(차트 기본)로 동작하게 분기.
          local.monitoring_use_ebs ? {
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
          } : {}
        )
      }
    })
  ]

  # [TIMEOUT-FIX] Fargate 기동 여유 (기본 300초 → 900초)
  timeout = 900
  wait    = true

  # [참고] depends_on은 정적이어야 해서 조건부로 만들 수 없음.
  #   Grafana ingress(ALB) 사용 시 ALB Controller가 먼저 있어야 하므로 의존을 유지.
  #   ingress를 끈 환경에서도 이 의존이 해는 없음(ALB Controller는 dev/prod 모두 설치되므로).
  #   단 alb_controller가 설치되지 않는 환경이 생기면 이 의존을 재검토할 것.
  depends_on = [helm_release.alb_controller]
}

resource "helm_release" "keda" {
  # [변경 이유] 기존: count = local.monitoring_enabled (모니터링과 한 묶음).
  #   KEDA는 관측(Prometheus/Grafana)이 아니라 이벤트 기반 오토스케일러로,
  #   AI 워커(Redis 큐)를 dev/prod 모두 스케일해야 하므로 모니터링과 생명주기가 다름.
  #   enable_keda로 분리해 모니터링과 독립적으로 켜고 끌 수 있게 함.
  count = local.keda_enabled ? 1 : 0

  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = var.chart_versions.keda
  namespace        = "keda"
  create_namespace = true
}
