#!/usr/bin/env bash
# =============================================================================
# teardown.sh — TaskFarm 야간 비용 절감 (내리기)
#
# 모든 값(계정/인스턴스 ID)을 동적으로 조회 → 하드코딩 없음, git에 올려도 안전.
# 순서: 앱 scale 0 → RDS replica destroy → RDS stop
#       → 노드그룹 destroy → NAT GW destroy → bastion/NAT인스턴스 stop
#
# 위치: team4-taskfarm-infra/scripts/teardown.sh  (infra 레포 scripts 폴더)
# 사용: ./scripts/teardown.sh
# 전제: AWS_PROFILE 설정됨(team4 계정), 09~18시 작업시간 내
# =============================================================================
set -uo pipefail   # -e 는 일부러 뺌(한 단계 실패해도 나머지 진행)

# --- 설정값 (민감하지 않은 것만 하드코딩) -----------------------------------
REGION="ap-northeast-2"
EXPECTED_ACCOUNT_TAG="team4"   # 이 태그가 리소스에 있어야 우리 것
CLUSTER_PROD="team4-prod-eks"
CLUSTER_DEV="team4-dev-eks"
NODEGROUP_PROD="team4-prod-node-group"
NS_PROD="taskfarm-prod"
NS_DEV="taskfarm-dev"

# 인스턴스 Name 태그 (ID는 동적 조회)
TAG_DEV_NAT="team4-dev-nat-instance"
TAG_PROD_BASTION="team4-prod-bastion"

# infra 디렉토리 = 스크립트 위치 기준 상대경로 (어느 PC든 동작)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../infra/envs/prod/infra"

echo "================================================================"
echo " TaskFarm 내리기 시작 — $(date '+%H:%M:%S')"
echo "================================================================"

# --- 0. 계정/시간 안전장치 --------------------------------------------------
ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$ACCOUNT" ]; then
  echo "[중단] AWS 자격증명 없음. AWS_PROFILE 설정 확인 (export AWS_PROFILE=...)"
  exit 1
fi
echo "[정보] 현재 계정: $ACCOUNT"
# 우리 클러스터가 이 계정에 있는지로 '맞는 계정인지' 검증
if ! aws eks describe-cluster --name "$CLUSTER_PROD" --region "$REGION" >/dev/null 2>&1; then
  echo "[중단] 이 계정($ACCOUNT)에서 $CLUSTER_PROD 를 못 찾음. 잘못된 계정/프로파일?"
  echo "       AWS_PROFILE 확인 후 다시 실행."
  exit 1
fi
echo "[OK] $CLUSTER_PROD 확인 — 올바른 계정."

HOUR=$(date +%H)
if [ "$HOUR" -ge 18 ] || [ "$HOUR" -lt 9 ]; then
  echo "[경고] 현재 ${HOUR}시 — AWS 작업시간(09~18시) 밖. 차단될 수 있음."
  read -p "그래도 진행? (yes/no): " ans
  [ "$ans" = "yes" ] || { echo "중단."; exit 0; }
fi

# --- 인스턴스 ID 동적 조회 (Name 태그로) ------------------------------------
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

# --- 1. 앱 scale 0 (prod + dev) ---------------------------------------------
echo ""
echo "[1/6] 앱 scale 0..."
kubectl config use-context "arn:aws:eks:${REGION}:${ACCOUNT}:cluster/${CLUSTER_PROD}" >/dev/null 2>&1
kubectl scale deployment --all -n "$NS_PROD" --replicas=0 2>/dev/null || echo "  prod scale 스킵"
kubectl config use-context "arn:aws:eks:${REGION}:${ACCOUNT}:cluster/${CLUSTER_DEV}" >/dev/null 2>&1
kubectl scale deployment --all -n "$NS_DEV" --replicas=0 2>/dev/null || echo "  dev scale 스킵"
echo "[1/6] 앱 scale 0 완료."

# --- 2. RDS replica destroy (terraform) -------------------------------------
echo ""
echo "[2/6] RDS replica destroy (terraform)..."
cd "$INFRA_DIR" || { echo "[중단] infra 디렉토리 못 찾음: $INFRA_DIR"; exit 1; }
terraform destroy -target='module.rds.aws_db_instance.read_replica[0]' -auto-approve
echo "[2/6] RDS replica destroy 완료."

# --- 3. RDS stop (prod + dev) — ID도 동적 조회 ------------------------------
echo ""
echo "[3/6] RDS stop..."
for db in $(aws rds describe-db-instances --region "$REGION" \
              --query "DBInstances[?starts_with(DBInstanceIdentifier,'team4') && DBInstanceStatus=='available'].DBInstanceIdentifier" \
              --output text 2>/dev/null); do
  aws rds stop-db-instance --db-instance-identifier "$db" --region "$REGION" >/dev/null 2>&1 \
    && echo "  $db stopping" || echo "  $db stop 실패(replica?)"
done
echo "[3/6] RDS stop 완료."

# --- 4. 노드그룹 destroy (terraform) ----------------------------------------
echo ""
echo "[4/6] 노드그룹 destroy (terraform, 드레이닝 ~8분)..."
terraform destroy -target='module.eks.aws_eks_node_group.main[0]' -auto-approve
echo "[4/6] 노드그룹 destroy 완료."

# --- 5. NAT Gateway destroy (terraform, 6개) --------------------------------
echo ""
echo "[5/6] NAT Gateway destroy (terraform)..."
terraform destroy \
  -target='module.vpc.aws_nat_gateway.nat["ap-northeast-2a"]' \
  -target='module.vpc.aws_nat_gateway.nat["ap-northeast-2c"]' \
  -target='module.vpc.aws_eip.nat["ap-northeast-2a"]' \
  -target='module.vpc.aws_eip.nat["ap-northeast-2c"]' \
  -target='module.vpc.aws_route.private_nat_gateway["ap-northeast-2a"]' \
  -target='module.vpc.aws_route.private_nat_gateway["ap-northeast-2c"]' \
  -auto-approve
echo "[5/6] NAT Gateway destroy 완료."

# --- 6. bastion + dev NAT 인스턴스 stop --------------------------------------
echo ""
echo "[6/6] bastion + dev NAT 인스턴스 stop..."
STOP_IDS=""
[ -n "$DEV_NAT_ID" ] && STOP_IDS="$STOP_IDS $DEV_NAT_ID"
[ -n "$BASTION_ID" ] && STOP_IDS="$STOP_IDS $BASTION_ID"
if [ -n "$STOP_IDS" ]; then
  aws ec2 stop-instances --instance-ids $STOP_IDS --region "$REGION" >/dev/null
  echo "  stop 요청:$STOP_IDS"
else
  echo "  stop할 인스턴스 없음(태그 확인)"
fi
echo "[6/6] 인스턴스 stop 완료."

echo ""
echo "================================================================"
echo " 내리기 완료 — $(date '+%H:%M:%S')"
echo " 남은 과금: EKS 컨트롤플레인(유지 필수), 정지 RDS 스토리지(미미)"
echo "================================================================"
