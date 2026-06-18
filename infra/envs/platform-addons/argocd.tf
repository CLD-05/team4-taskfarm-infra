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

        # [참고] ingress=false 유지. ArgoCD UI는 dev/prod 모두 port-forward로 접근하는
        #   전제. prod에서 UI를 외부 노출하려면 ingress(ALB)+ESO(admin 비밀번호)를
        #   추가해야 하나, 운영 UI를 공개 노출하지 않는 게 보안상 안전해 현행 유지.
        ingress = {
          enabled = false
        }
      }

      configs = {
        params = {
          # [참고] server.insecure=true는 ArgoCD 서버 자체 TLS를 끔.
          #   ALB/Ingress에서 TLS를 종단하는 구성이면 맞는 설정. 단 port-forward로만
          #   접근하는 현재는 내부 통신이라 무방. 추후 ingress로 외부 노출 시
          #   TLS 종단 지점(ALB)에 인증서가 있는지 확인 필요.
          "server.insecure" = true
        }
      }
    })
  ]
}
