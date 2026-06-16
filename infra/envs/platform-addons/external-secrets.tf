# =====================================================================
# [담당 B] External Secrets Operator (ESO)
# =====================================================================
# 역할: AWS Secrets Manager의 시크릿을 K8s Secret으로 동기화.
#       (Gemini API 키 등 → Pod에 평문 없이 주입. 이 앱 보안 핵심)
# 방식: helm_release(ESO) + IRSA(Secrets Manager 읽기 권한)
#
# 구현 체크리스트:
#  [ ] IRSA role 생성 (OIDC trust)
#      - serviceaccount: external-secrets / external-secrets
#      - IAM policy: secretsmanager:GetSecretValue, DescribeSecret (해당 시크릿 ARN으로 좁히기)
#  [ ] helm_release "external-secrets"
#      - repository: https://charts.external-secrets.io
#      - chart: external-secrets
#      - version: var.chart_versions.external_secrets (고정!)
#      - namespace: external-secrets (create_namespace=true)
#      - serviceAccount IRSA annotation
#  [ ] (선택) ClusterSecretStore 매니페스트 — kubernetes_manifest 또는 앱 레포 매니페스트로.
#      ※ ClusterSecretStore/ExternalSecret 리소스는 config 레포(K8s 매니페스트)에서
#        관리할 수도 있음. 팀 합의 — 여기선 ESO 설치까지만 권장.
#
# ⚠️ Secrets Manager에 실제 시크릿이 있어야(secrets 모듈 — infra). ARN을 remote_state로 받거나 변수로.
# ⚠️ IRSA policy는 특정 시크릿 ARN으로 좁힐 것 (전체 secretsmanager:* 금지 — 최소권한).

# resource "aws_iam_role" "external_secrets" { ... }
# resource "helm_release" "external_secrets" { ... }
