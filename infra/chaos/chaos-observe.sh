#!/bin/bash
# 사용: bash chaos-observe.sh <FIS템플릿ID>  (없으면 관측만)
TID=$1; NS=taskfarm-prod
LOG="chaos-run-$(date +%Y%m%d-%H%M%S).log"
echo "=== 실험 시작 $(date) ===" | tee -a "$LOG"

# 가용성 폴링 (백그라운드)
( while true; do
    echo "$(date +%T) health=$(curl -s -o /dev/null -w '%{http_code}' https://taskfarm.site/actuator/health)" >> "$LOG"
    sleep 2; done ) & POLL=$!

# 파드 변화 (백그라운드)
kubectl get pods -n $NS -o wide -w >> "$LOG" 2>&1 & WATCH=$!

# FIS 실험 실행
if [ -n "$TID" ]; then
  EID=$(aws fis start-experiment --region ap-northeast-2 \
        --experiment-template-id "$TID" --query "experiment.id" --output text)
  echo "$(date +%T) FIS 시작 id=$EID" | tee -a "$LOG"
fi

echo "관측 중... 끝나면 Enter"
read
kill $POLL $WATCH 2>/dev/null
echo "=== 종료. 로그파일: $LOG ===" | tee -a "$LOG"