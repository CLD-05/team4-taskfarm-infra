#!/bin/bash
NS=taskfarm-prod
POD=$(kubectl get pods -n $NS -l app=taskfarm-user -o jsonpath='{.items[0].metadata.name}')
echo "💥 죽일 파드: $POD"
kubectl delete pod -n $NS "$POD"
echo "👀 self-heal 관측 (Ctrl+C 종료):"
kubectl get pods -n $NS -l app=taskfarm-user -w