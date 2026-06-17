# =====================================================================
# [담당 C] ArgoCD (+ root app / app-of-apps)
# =====================================================================
# 역할: GitOps CD. config 레포(K8s 매니페스트)를 watch해 클러스터에 자동 동기화.
# 방식: helm_release(ArgoCD) + root Application(app-of-apps 패턴)
#
# 구현 체크리스트:
#  [ ] helm_release "argocd"
#      - repository: https://argoproj.github.io/argo-helm
#      - chart: argo-cd
#      - version: var.chart_versions.argocd (고정!)
#      - namespace: argocd (create_namespace=true)
#      - values: server.ingress (ALB) — ⚠️ ALB Controller(A) 먼저 떠야 함 → depends_on
#      - server.ingress.ingressClassName = alb, annotations(alb scheme 등)
#  [ ] root Application 매니페스트 (app-of-apps)
#      - kubernetes_manifest 또는 helm values의 server.additionalApplications
#      - source.repoURL = config 레포 (team4-taskfarm-config)
#      - source.path = 환경별 매니페스트 경로 (envs/dev, envs/prod)
#      - destination = in-cluster
#      - syncPolicy.automated (prune·selfHeal)
#
# ⚠️ 의존성: ALB Controller(담당 A) 먼저 → ArgoCD ingress가 ALB 받음.
#    depends_on = [helm_release.alb_controller] 권장.
# ⚠️ admin 초기 비번: ArgoCD가 자동생성(secret). 또는 values로 설정. 평문 커밋 금지.
# ⚠️ root app의 repoURL/path는 config 레포 구조와 합의 필요 (C 담당 ↔ config 담당).

# resource "helm_release" "argocd" { ... }
# resource "kubernetes_manifest" "root_app" { ... }

# =====================================================================
# [담당 C] ArgoCD
# =====================================================================
# 역할:
# - GitOps CD 도구인 ArgoCD를 EKS 클러스터에 설치한다.
# - ArgoCD는 이후 config repo를 감시하여 애플리케이션 배포를 담당한다.
#
# 이번 PR 범위:
# - helm_release "argocd" 로 ArgoCD 설치까지만 담당한다.
#
# 제외한 것:
# - kubernetes_manifest 로 root Application을 만들지 않는다.
#
# 제외 이유:
# - ArgoCD Application은 ArgoCD CRD가 클러스터에 설치된 뒤에만 생성 가능하다.
# - 첫 apply 시점에는 아직 ArgoCD CRD가 없으므로,
#   kubernetes_manifest "argocd_root_app"은 plan/apply 단계에서 실패할 수 있다.
# - root Application은 추후 Helm additionalApplications 또는 별도 apply 단계로 분리한다.
#
# 주의:
# - ArgoCD Ingress는 ALB Controller 및 노출 정책 확정 후 별도 작업으로 추가한다.
# - 초기 admin 비밀번호는 ArgoCD가 생성하는 Secret을 사용하며 평문 커밋하지 않는다.


# =====================================================================


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
}