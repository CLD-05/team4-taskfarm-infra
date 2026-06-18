# modules/eks/eks-sg.tf

# 클러스터(컨트롤플레인) SG
resource "aws_security_group" "cluster" {
  name        = "${var.name_prefix}-eks-cluster-sg"
  description = "EKS cluster control plane SG"
  vpc_id      = var.vpc_id

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-eks-cluster-sg" })
}

# 노드 SG (node_group = prod만)
resource "aws_security_group" "node" {
  count       = local.enabled_node_group ? 1 : 0
  name        = "${var.name_prefix}-eks-node-sg"
  description = "EKS worker node SG"
  vpc_id      = var.vpc_id

  # 노드끼리 통신
  ingress {
    description = "Node to node"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # 클러스터 → 노드 (kubelet 등)
  ingress {
    description     = "Cluster to node"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.cluster.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-node-sg"
    # EKS가 노드 SG를 인식하도록 (선택)
    "kubernetes.io/cluster/${var.name_prefix}-eks" = "owned"
  })
}

# 클러스터 API (443) 버그 패치
resource "aws_security_group_rule" "cluster_ingress_node_https" {
  count                    = local.enabled_node_group ? 1 : 0
  description              = "Node to cluster API server (kubelet join)"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node[0].id
}

locals {
  # main.tf가 참조: cluster SG는 항상, node SG는 prod만(없으면 cluster SG로 폴백)
  cluster_sg_id = aws_security_group.cluster.id
  node_sg_id    = local.enabled_node_group ? aws_security_group.node[0].id : aws_security_group.cluster.id
}
