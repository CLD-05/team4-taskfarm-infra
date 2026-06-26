#!/bin/bash
TID=$1; NS=taskfarm-prod
TS=$(date +%Y%m%d-%H%M%S)
HLOG="chaos-health-$TS.log"; PLOG="chaos-pods-$TS.log"

# 가용성 — curl 타임아웃(-m 2)으로 안 멈춤, 다운이면 000 찍힘
( while true; do
    CODE=$(curl -s -m 2 -o /dev/null -w '%{http_code}' https://taskfarm.site/actuator/health)
    echo "$(date +%T) $CODE" >> "$HLOG"; sleep 1
  done ) & POLL=$!

# 파드는 별도 파일로 (섞이지 않게)
kubectl get pods -n $NS -l app=taskfarm-user -o wide -w >> "$PLOG" 2>&1 & WATCH=$!

if [ -n "$TID" ]; then
  EID=$(aws fis start-experiment --region ap-northeast-2 --experiment-template-id "$TID" --query "experiment.id" --output text)
  echo "FIS started: $EID"
fi
echo "관측 중... 끝나면 Enter"; read
kill $POLL $WATCH 2>/dev/null
echo "health: $HLOG / pods: $PLOG"