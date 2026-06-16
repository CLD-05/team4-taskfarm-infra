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
