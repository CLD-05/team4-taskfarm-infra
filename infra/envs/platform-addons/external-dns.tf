# =====================================================================
# [담당 B] ExternalDNS
# =====================================================================
# 역할: Ingress/Service의 호스트명을 Route53 레코드로 자동 생성·관리.
# 방식: helm_release + IRSA(Route53 변경 권한)
#
# ⚠️ dev/prod 정책 차이 (우리 결정):
#   - dev:  sync  (레코드 생성·삭제 다 함 — 실험 환경)
#   - prod: upsert-only (생성·수정만, 삭제 안 함 — 실수로 레코드 날리는 사고 방지)
#   → var.env로 분기: policy = var.env == "prod" ? "upsert-only" : "sync"
#
# 구현 체크리스트:
#  [ ] IRSA role 생성 (OIDC trust)
#      - serviceaccount: external-dns / external-dns
#      - IAM policy: route53:ChangeResourceRecordSets (해당 HostedZone ARN으로 좁히기),
#                    route53:ListHostedZones, ListResourceRecordSets
#  [ ] helm_release "external-dns"
#      - repository: https://kubernetes-sigs.github.io/external-dns/
#      - chart: external-dns
#      - version: var.chart_versions.external_dns (고정!)
#      - namespace: external-dns (create_namespace=true)
#      - set: policy = (위 dev/prod 분기)
#      - set: domainFilters = [우리 도메인]  (route53 모듈 output 또는 변수)
#      - set: txtOwnerId = local.cluster_name (소유권 식별)
#
# ⚠️ HostedZone ID/도메인이 필요 → route53 모듈 output을 remote_state로 받거나 변수로.
# ⚠️ Route53 권한은 해당 zone ARN으로 좁힐 것 (전체 route53:* 금지).

# resource "aws_iam_role" "external_dns" { ... }
# resource "helm_release" "external_dns" { ... }
