locals {
  use_pod_identity = var.env == "prod" # prod=Pod Identity, dev=IRSA
  oidc_url         = replace(data.terraform_remote_state.infra.outputs.oidc_provider_url, "https://", "")

  trust_irsa = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.terraform_remote_state.infra.outputs.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = { StringEquals = {
        "${local.oidc_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        "${local.oidc_url}:aud" = "sts.amazonaws.com"
      } }
    }]
  })

  trust_pod_identity = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

resource "aws_iam_role" "alb_controller" {
  name               = "team4-${var.env}-alb-controller"
  assume_role_policy = local.use_pod_identity ? local.trust_pod_identity : local.trust_irsa
  tags               = { Name = "team4-${var.env}-alb-controller" }
}

resource "aws_iam_policy" "alb_controller" {
  name   = "team4-${var.env}-alb-controller-policy"
  policy = file("${path.module}/policies/alb-controller-iam-policy.json")
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

resource "aws_eks_pod_identity_association" "alb_controller" {
  count = local.use_pod_identity ? 1 : 0

  cluster_name    = local.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.alb_controller.arn
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_versions.alb_controller
  namespace  = "kube-system"

  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  # IRSA(dev)일 때만 role-arn 어노테이션 (Pod Identity는 불필요)
  dynamic "set" {
    for_each = local.use_pod_identity ? [] : [1]
    content {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.alb_controller.arn
    }
  }

  set {
    name  = "clusterName"
    value = local.cluster_name
  }
  set {
    name  = "region"
    value = data.aws_region.current.name
  }
  set {
    name  = "vpcId"
    value = data.terraform_remote_state.infra.outputs.vpc_id
  }

  depends_on = [aws_iam_role_policy_attachment.alb_controller]
}
