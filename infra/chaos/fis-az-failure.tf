resource "aws_fis_experiment_template" "az_failure" {
  description = "Lv3: AZ 2a 네트워크 차단 -> 다른 AZ(2c) 페일오버 관측"
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = aws_cloudwatch_metric_alarm.chaos_guard.arn
  }

  action {
    name      = "disrupt-az-2a"
    action_id = "aws:network:disrupt-connectivity"
    parameter {
      key   = "duration"
      value = "PT5M"
    }
    parameter {
      key   = "scope"
      value = "availability-zone"
    }
    target {
      key   = "Subnets"
      value = "az-2a-subnets"
    }
  }

  target {
    name           = "az-2a-subnets"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"

    resource_tag { # ← 이거 추가! (기본 식별자)
      key   = "Team"
      value = "team4"
    }

    filter {
      path   = "AvailabilityZone"
      values = ["ap-northeast-2a"]
    }
    filter {
      path   = "VpcId"
      values = [var.prod_vpc_id] # prod VPC로 좁힘 (dev team4 서브넷 제외)
    }
  }

  tags = { Name = "team4-chaos-az-failure" }
}
