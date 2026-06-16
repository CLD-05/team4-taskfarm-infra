# modules/eks/eks-iam.tf

# ── 클러스터 role (컨트롤플레인) ──
data "aws_iam_policy_document" "cluster_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.name_prefix}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
  tags               = merge(var.tags, { Name = "${var.name_prefix}-eks-cluster-role" })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ── 노드 role (node_group = prod만) ──
data "aws_iam_policy_document" "node_assume" {
  count = local.enabled_node_group ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  count              = local.enabled_node_group ? 1 : 0
  name               = "${var.name_prefix}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume[0].json
  tags               = merge(var.tags, { Name = "${var.name_prefix}-eks-node-role" })
}

# 노드에 필요한 관리형 정책 3종
resource "aws_iam_role_policy_attachment" "node_worker" {
  count      = local.enabled_node_group ? 1 : 0
  role       = aws_iam_role.node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  count      = local.enabled_node_group ? 1 : 0
  role       = aws_iam_role.node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  count      = local.enabled_node_group ? 1 : 0
  role       = aws_iam_role.node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ── Fargate execution role (fargate = dev만) ──
data "aws_iam_policy_document" "fargate_assume" {
  count = local.enabled_fargate_profile ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fargate" {
  count              = local.enabled_fargate_profile ? 1 : 0
  name               = "${var.name_prefix}-eks-fargate-role"
  assume_role_policy = data.aws_iam_policy_document.fargate_assume[0].json
  tags               = merge(var.tags, { Name = "${var.name_prefix}-eks-fargate-role" })
}

resource "aws_iam_role_policy_attachment" "fargate_exec" {
  count      = local.enabled_fargate_profile ? 1 : 0
  role       = aws_iam_role.fargate[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

# ── EBS CSI Driver IRSA Role (node_group = prod만) ──
# EBS CSI는 EKS managed addon → Pod Identity 미지원, IRSA만 가능.
# 이 addon을 eks-addons.tf가 설치하므로 그 role도 여기서(같은 모듈) 생성 — 응집도.
# dev(Fargate)는 EBS 자체를 안 써서 불필요 → count로 prod만.
#
# trust: EKS OIDC(Federated) + 정해진 SA(kube-system:ebs-csi-controller-sa)
# policy: AWS 관리형 AmazonEBSCSIDriverPolicy (직접 안 짜도 됨)
resource "aws_iam_role" "ebs_csi" {
  count = local.enabled_node_group ? 1 : 0

  name = "${var.name_prefix}-ebs-csi-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.this.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url}:aud" = "sts.amazonaws.com"
          "${local.oidc_url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }]
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-ebs-csi-irsa" })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count      = local.enabled_node_group ? 1 : 0
  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ── 로컬: main.tf가 참조할 role ARN (내부 생성으로 통일) ──
locals {
  # OIDC provider URL (https:// 제거) — IRSA trust condition key용
  oidc_url = replace(aws_iam_openid_connect_provider.this.url, "https://", "")

  cluster_role_arn = aws_iam_role.cluster.arn
  node_role_arn    = local.enabled_node_group ? aws_iam_role.node[0].arn : null
  fargate_role_arn = local.enabled_fargate_profile ? aws_iam_role.fargate[0].arn : null
  ebs_csi_role_arn = local.enabled_node_group ? aws_iam_role.ebs_csi[0].arn : null
}
