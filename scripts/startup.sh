#!/usr/bin/env bash
# =============================================================================
# startup.sh — TaskFarm 아침 복구 (올리기)
#
# 순서(teardown 역순): 인스턴스 start → RDS start → terraform init
#                      → NAT GW apply → 노드그룹 apply
#                      → RDS replica apply(primary available 후!) → 앱 scale 1
#
# 위치: team4-taskfarm-infra/scripts/startup.sh
# 사용: ./scripts/startup.sh
# =============================================================================
set -uo pipefail

REGION="ap-northeast-2"
CLUSTER_PROD="team4-prod-eks"
CLUSTER_DEV="team4-dev-eks"
NS_PROD="taskfarm-prod"
NS_DEV="taskfarm-dev"

TAG_DEV_NAT="team4-dev-nat-instance"
TAG_PROD_BASTION="team4-prod-bastion"

# infra 디렉토리 = 스크립트 위치 기준 상대경로
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../infra/envs/prod/infra"

# 실패 추적
FAIL_COUNT=0
FAILED_STEPS=""

run_tf() {
  local label="$1"; shift
  echo ">>> terraform $* "
  if terraform "$@"; then
    echo "    [OK] $label"
  else
    echo ""
    echo "    ############################################################"
    echo "    ## [실패] $label — terraform 비정상 종료!"
    echo "    ## 위 에러 확인. 이 리소스는 아직 안 올라왔을 수 있음."
    echo "    ############################################################"
    echo ""
    FAIL_COUNT=$((FAIL_COUNT+1))
    FAILED_STEPS="$FAILED_STEPS\n  - $label"
  fi
}

echo "================================================================"
echo " TaskFarm 올리기 시작 — $(date '+%H:%M:%S')"
echo "================================================================"

# --- 0. 계정 안전장치 (동적) ------------------------------------------------
ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$ACCOUNT" ]; then
  echo "[중단] AWS 자격증명 없음. export AWS_PROFILE=... 확인"
  exit 1
fi
echo "[정보] 현재 계정: $ACCOUNT"
# 우리 클러스터가 이 계정에 있는지로 검증
if ! aws eks describe-cluster --name "$CLUSTER_PROD" --region "$REGION" >/dev/null 2>&1; then
  echo "[중단] 이 계정($ACCOUNT)에서 $CLUSTER_PROD 못 찾음. 잘못된 계정/프로파일?"
  exit 1
fi
echo "[OK] $CLUSTER_PROD 확인 — 올바른 계정."

PROD_CTX="arn:aws:eks:${REGION}:${ACCOUNT}:cluster/${CLUSTER_PROD}"
DEV_CTX="arn:aws:eks:${REGION}:${ACCOUNT}:cluster/${CLUSTER_DEV}"

# --- 인스턴스 ID 동적 조회 --------------------------------------------------
find_instance() {
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$1" \
              "Name=instance-state-name,Values=running,stopped,stopping,pending" \
    --query "Reservations[].Instances[].InstanceId" --output text --region "$REGION" 2>/dev/null
}
DEV_NAT_ID=$(find_instance "$TAG_DEV_NAT")
BASTION_ID=$(find_instance "$TAG_PROD_BASTION")
echo "[정보] dev NAT 인스턴스: ${DEV_NAT_ID:-(없음)}"
echo "[정보] prod bastion:    ${BASTION_ID:-(없음)}"

# --- 1. bastion + dev NAT 인스턴스 start ------------------------------------
echo ""
echo "[1/7] bastion + dev NAT 인스턴스 start..."
START_IDS=""
[ -n "$DEV_NAT_ID" ] && START_IDS="$START_IDS $DEV_NAT_ID"
[ -n "$BASTION_ID" ] && START_IDS="$START_IDS $BASTION_ID"
if [ -n "$START_IDS" ]; then
  aws ec2 start-instances --instance-ids $START_IDS --region "$REGION" >/dev/null
  echo "  start 요청:$START_IDS"
else
  echo "  start할 인스턴스 없음(태그 확인)"
fi
echo "[1/7] 인스턴스 start 완료."

# --- 2. RDS start (prod + dev) — 먼저 던져놓고 뒤에서 available 대기 --------
echo ""
echo "[2/7] RDS start..."
aws rds start-db-instance --db-instance-identifier team4-prod-mysql --region "$REGION" >/dev/null 2>&1 \
  && echo "  prod RDS starting" || echo "  prod RDS start 스킵(이미 available?)"
aws rds start-db-instance --db-instance-identifier team4-dev-mysql --region "$REGION" >/dev/null 2>&1 \
  && echo "  dev RDS starting" || echo "  dev RDS start 스킵(이미 available?)"
echo "[2/7] RDS start 요청 완료."

# --- 3. terraform init (★ provider 보장 — 없으면 apply 전부 스킵됨) ---------
echo ""
echo "[3/7] terraform init..."
cd "$INFRA_DIR" || { echo "[중단] infra 디렉토리 못 찾음: $INFRA_DIR"; exit 1; }
if ! terraform init -input=false; then
  echo "[중단] terraform init 실패 — provider를 받지 못했습니다."
  echo "       (init 없이는 모든 apply가 스킵되어 인프라가 안 올라옵니다)"
  exit 1
fi
echo "[3/7] terraform init 완료."

# --- 4. NAT Gateway apply (terraform, 6개) ----------------------------------
echo ""
echo "[4/7] NAT Gateway apply (terraform)..."
run_tf "NAT Gateway apply" apply \
  -target='module.vpc.aws_nat_gateway.nat["ap-northeast-2a"]' \
  -target='module.vpc.aws_nat_gateway.nat["ap-northeast-2c"]' \
  -target='module.vpc.aws_eip.nat["ap-northeast-2a"]' \
  -target='module.vpc.aws_eip.nat["ap-northeast-2c"]' \
  -target='module.vpc.aws_route.private_nat_gateway["ap-northeast-2a"]' \
  -target='module.vpc.aws_route.private_nat_gateway["ap-northeast-2c"]' \
  -auto-approve
echo "[4/7] NAT Gateway apply 단계 종료."

# --- 5. 노드그룹 apply (terraform) ------------------------------------------
echo ""
echo "[5/8] 노드그룹 apply (terraform)..."
run_tf "노드그룹 apply" apply -target='module.eks.aws_eks_node_group.main[0]' -auto-approve
echo "[5/8] 노드그룹 apply 단계 종료."

# --- 5.5. EBS CSI 애드온 보장 (★ 노드 destroy/apply 하면 CSI가 증발함!) ------
#   증상: CSI 없으면 PVC 볼륨(Prometheus 등)이 노드에 안 붙어 Pending 무한대기
#         → 그라파나 접속 불가. (2026-06-30 이 문제로 한참 헤맴)
#   노드에 의존하는 애드온이라 노드 apply 뒤에 반드시 재확인.
echo ""
echo "[6/8] EBS CSI 애드온 확인/복구..."
if aws eks list-addons --cluster-name "$CLUSTER_PROD" --region "$REGION" \
     --query 'addons' --output text 2>/dev/null | grep -q 'aws-ebs-csi-driver'; then
  echo "  [OK] EBS CSI 애드온 이미 존재."
else
  echo "  [경고] EBS CSI 애드온 없음 → terraform으로 복구..."
  run_tf "EBS CSI 애드온 복구" apply -target='module.eks.aws_eks_addon.ebs_csi[0]' -auto-approve
  echo "  CSI 파드 뜨는 중(1~2분). 볼륨 붙이려면 필요."
fi
echo "[6/8] EBS CSI 애드온 단계 종료."

# --- 7. RDS replica apply (★ primary available 대기 후!) --------------------
echo ""
echo "[7/8] RDS primary가 available 될 때까지 대기..."
if aws rds wait db-instance-available --db-instance-identifier team4-prod-mysql --region "$REGION"; then
  echo "  primary available 확인. replica 재생성..."
  run_tf "RDS replica apply" apply -target='module.rds.aws_db_instance.read_replica[0]' -auto-approve
else
  echo "  [경고] primary available 대기 실패/타임아웃. replica 수동 확인 필요."
  FAIL_COUNT=$((FAIL_COUNT+1))
  FAILED_STEPS="$FAILED_STEPS\n  - RDS replica apply (primary 대기 실패)"
fi
echo "[7/8] RDS replica 단계 종료."

# --- 8. 앱 scale 1 (prod + dev) ---------------------------------------------
echo ""
echo "[8/8] 앱 scale 1..."
kubectl config use-context "$PROD_CTX" >/dev/null 2>&1
kubectl scale deployment --all -n "$NS_PROD" --replicas=1 2>/dev/null || echo "  prod scale 스킵"
kubectl config use-context "$DEV_CTX" >/dev/null 2>&1
kubectl scale deployment --all -n "$NS_DEV" --replicas=1 2>/dev/null || echo "  dev scale 스킵"
echo "[8/8] 앱 scale 1 완료."

# --- 결과 요약 --------------------------------------------------------------
echo ""
echo "================================================================"
echo " 올리기 종료 — $(date '+%H:%M:%S')"
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo " ✅ 모든 terraform 단계 성공."
else
  echo " ⚠️⚠️ terraform $FAIL_COUNT 개 단계 실패! 아래는 아직 안 올라왔을 수 있음:"
  echo -e "$FAILED_STEPS"
  echo " → 위 단계를 수동으로 다시 apply 하세요."
fi
echo ""
echo " 확인: kubectl get nodes"
echo "       kubectl get applications -n argocd  (OutOfSync면 수동 sync)"
echo "       prod 수동 sync: kubectl patch application taskfarm-user-prod -n argocd --type merge -p '{\"operation\":{\"sync\":{}}}'"
echo ""
echo " ★ 모니터링(그라파나) 안 뜨면 — CSI 복구 후 Prometheus 파드가 옛 상태일 수 있음:"
echo "   kubectl get pods -n monitoring | grep prometheus   (Init/Pending이면 아래)"
echo "   kubectl delete pod prometheus-kube-prometheus-stack-prometheus-0 -n monitoring"
echo "   → 재시작하면 CSI가 볼륨 붙여서 Running 됨."
echo "================================================================"

[ "$FAIL_COUNT" -eq 0 ] || exit 1