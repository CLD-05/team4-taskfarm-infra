# platform-addons/argocd.tf

# [참고] ArgoCD는 dev/prod 모두 GitOps 배포에 필요하므로 항상 설치(분기 없음).
#   enable 플래그를 두지 않은 이유: 이 addon이 없으면 config 레포 기반 배포 자체가
#   불가능해, 사실상 필수 컴포넌트라 끄는 시나리오가 없음.
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_versions.argocd
  namespace        = "argocd"
  create_namespace = true

  values = [
    yamlencode({
      crds = {
        install = true
      }

      server = {
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled = false
        }
      }

      configs = {
        params = {
          "server.insecure" = true
        }
      }
    })
  ]

  # [WEBHOOK-FIX] ALB Controller가 Ready 된 뒤 설치
  depends_on = [helm_release.alb_controller]
}

