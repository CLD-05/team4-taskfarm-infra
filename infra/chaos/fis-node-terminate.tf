resource "aws_fis_experiment_template" "node_terminate" {
  description = "Lv2: prod EKS 노드 1개 종료 -> 재배치/ASG 교체 관측"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = aws_cloudwatch_metric_alarm.chaos_guard.arn
  }

  action {
    name      = "terminate-node"
    action_id = "aws:ec2:terminate-instances"
    target {
      key   = "Instances"
      value = "eks-nodes"
    }
  }

  target {
    name           = "eks-nodes"
    resource_type  = "aws:ec2:instance"
    selection_mode = "COUNT(1)"
    resource_tag {
      key   = "eks:cluster-name"
      value = "team4-prod-eks"
    }
    filter {
      path   = "Placement.AvailabilityZone"
      values = ["ap-northeast-2a"]
    }
    filter {
      path   = "State.Name"
      values = ["running"]
    }
  }

  tags = { Name = "team4-chaos-node-terminate" }
}
