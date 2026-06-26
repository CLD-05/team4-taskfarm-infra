#!/usr/bin/env bash
# =============================================================================
# startup.sh — TaskFarm 아침 복구 (올리기)
#
# 모든 값 동적 조회 → 하드코딩 없음, git에 올려도 안전.
# 순서(teardown 역순): bastion/NAT인스턴스 start → RDS start → NAT GW apply
#       → 노드그룹 apply → RDS replica apply(primary available 후!) → 앱 scale 1
#
# ⚠️ 핵심: RDS replica는 primary 'available' 후에만 생성 가능 → wait로 대기.
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
RDS_PRIMARY="team4-prod-mysql"   # replica wait 대상 (primary 식별자)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../infra/envs/prod/infra"

echo "================================================================"
echo " TaskFarm 올리기 시작 — $(date '+%H:%M:%S')"
echo "================================================================"

# --- 0. 계정 안전장치 -------------------------------------------------------
ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$ACCOUNT" ]; then
  echo "[중단] AWS 자격증명 없음. AWS_PROFILE 확인."
  exit 1
fi
echo "[정보] 현재 계정: $ACCOUNT"
if ! aws eks describe-cluster --name "$CLUSTER_PROD" --region "$REGION" >/dev/null 2>&1; then
  echo "[중단] 이 계정($ACCOUNT)에서 $CLUSTER_PROD 못 찾음. 잘못된 프로파일?"
  exit 1
fi
echo "[OK] $CLUSTER_PROD 확인 — 올바른 계정."

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
echo "[1/6] bastion + dev NAT 인스턴스 start..."
START_IDS=""
[ -n "$DEV_NAT_ID" ] && START_IDS="$START_IDS $DEV_NAT_ID"
[ -n "$BASTION_ID" ] && START_IDS="$START_IDS $BASTION_ID"
if [ -n "$START_IDS" ]; then
  aws ec2 start-instances --instance-ids $START_IDS --region "$REGION" >/dev/null
  echo "  start 요청:$START_IDS"
else
  echo "  start할 인스턴스 없음(태그 확인)"
fi

# --- 2. RDS start (정지된 team4 RDS 전부) -----------------------------------
echo ""
echo "[2/6] RDS start..."
for db in $(aws rds describe-db-instances --region "$REGION" \
              --query "DBInstances[?starts_with(DBInstanceIdentifier,'team4') && DBInstanceStatus=='stopped'].DBInstanceIdentifier" \
              --output text 2>/dev/null); do
  aws rds start-db-instance --db-instance-identifier "$db" --region "$REGION" >/dev/null 2>&1 \
    && echo "  $db starting" || echo "  $db start 실패"
done

# --- 3. NAT Gateway apply (terraform, 6개) ----------------------------------
echo ""
echo "[3/6] NAT Gateway apply (terraform)..."
cd "$INFRA_DIR" || { echo "[중단] infra 디렉토리 못 찾음: $INFRA_DIR"; exit 1; }
terraform apply \
  -target='module.vpc.aws_nat_gateway.nat["ap-northeast-2a"]' \
  -target='module.vpc.aws_nat_gateway.nat["ap-northeast-2c"]' \
  -target='module.vpc.aws_eip.nat["ap-northeast-2a"]' \
  -target='module.vpc.aws_eip.nat["ap-northeast-2c"]' \
  -target='module.vpc.aws_route.private_nat_gateway["ap-northeast-2a"]' \
  -target='module.vpc.aws_route.private_nat_gateway["ap-northeast-2c"]' \
  -auto-approve
echo "[3/6] NAT Gateway apply 완료."

# --- 4. 노드그룹 apply (terraform) ------------------------------------------
echo ""
echo "[4/6] 노드그룹 apply (terraform)..."
terraform apply -target='module.eks.aws_eks_node_group.main[0]' -auto-approve
echo "[4/6] 노드그룹 apply 완료."

# --- 5. RDS replica apply (primary available 대기 후!) ----------------------
echo ""
echo "[5/6] RDS primary($RDS_PRIMARY) available 대기..."
aws rds wait db-instance-available --db-instance-identifier "$RDS_PRIMARY" --region "$REGION"
echo "  primary available 확인. replica 재생성..."
terraform apply -target='module.rds.aws_db_instance.read_replica[0]' -auto-approve
echo "[5/6] RDS replica apply 완료."

# --- 6. 앱 scale 1 (prod + dev) ---------------------------------------------
echo ""
echo "[6/6] 앱 scale 1..."
kubectl config use-context "arn:aws:eks:${REGION}:${ACCOUNT}:cluster/${CLUSTER_PROD}" >/dev/null 2>&1
kubectl scale deployment --all -n "$NS_PROD" --replicas=1 2>/dev/null || echo "  prod scale 스킵"
kubectl config use-context "arn:aws:eks:${REGION}:${ACCOUNT}:cluster/${CLUSTER_DEV}" >/dev/null 2>&1
kubectl scale deployment --all -n "$NS_DEV" --replicas=1 2>/dev/null || echo "  dev scale 스킵"
echo "[6/6] 앱 scale 1 완료."

echo ""
echo "================================================================"
echo " 올리기 완료 — $(date '+%H:%M:%S')"
echo " 확인: kubectl get nodes / kubectl get applications -n argocd"
echo "       prod 앱 OutOfSync면 수동 sync 필요할 수 있음."
echo "================================================================"
