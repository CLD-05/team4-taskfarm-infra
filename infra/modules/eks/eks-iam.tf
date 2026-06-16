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

# ── 로컬: main.tf가 참조할 role ARN (내부 생성으로 통일) ──
locals {
  cluster_role_arn = aws_iam_role.cluster.arn
  node_role_arn    = local.enabled_node_group ? aws_iam_role.node[0].arn : null
  fargate_role_arn = local.enabled_fargate_profile ? aws_iam_role.fargate[0].arn : null
}
