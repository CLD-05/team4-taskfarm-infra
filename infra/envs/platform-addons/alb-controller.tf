# =====================================================================
# [담당 A] AWS Load Balancer Controller
# =====================================================================
# 역할: Ingress 생성 시 ALB 자동 프로비저닝. Ingress·Service(LB) 처리.
# 방식: helm_release + IRSA (이 컨트롤러용 IAM role)
#
# 구현 체크리스트:
#  [ ] IRSA role 생성 (aws_iam_role + OIDC trust)
#      - trust: data.terraform_remote_state.infra.outputs.oidc_provider_arn/url 사용
#      - serviceaccount: kube-system / aws-load-balancer-controller
#  [ ] IAM policy 연결 (AWS 공식 정책 JSON — iam_policy.json 다운로드 후 aws_iam_policy)
#      https://github.com/kubernetes-sigs/aws-load-balancer-controller (docs의 정책)
#  [ ] helm_release "aws-load-balancer-controller"
#      - repository: https://aws.github.io/eks-charts
#      - chart: aws-load-balancer-controller
#      - version: var.chart_versions.alb_controller  (버전 고정!)
#      - namespace: kube-system
#      - set: clusterName = local.cluster_name
#      - set: serviceAccount.annotations (IRSA role arn)
#      - set: region, vpcId (remote_state에서)
#
# ⚠️ vpcId가 필요 → infra가 vpc_id도 output으로 내보내야 함 (이름 약속에 추가)
# ⚠️ 다른 addon이 ALB controller에 의존(ArgoCD/Grafana ALB ingress) → 먼저 떠야 함.
#    depends_on 또는 apply 순서로 보장.

# resource "aws_iam_role" "alb_controller" { ... }
# resource "helm_release" "alb_controller" { ... }
