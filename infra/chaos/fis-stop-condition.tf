resource "aws_cloudwatch_metric_alarm" "chaos_guard" {
  alarm_name          = "team4-chaos-guard-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10 # 1분에 5xx 50개↑ = 복구 실패 신호 → 실험 자동 중단
  dimensions = {
    LoadBalancer = "app/k8s-taskfarm-taskfarm-ab3bef4baa/17241a55a75f7035" # user 앱 ALB
  }
}
