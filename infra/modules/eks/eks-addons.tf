# modules/eks/eks-addons.tf

locals {
  # node_group(prod)에서만 켜는 addon
  enable_node_only_addons = var.compute_type == "node_group"

  # 버전이 빈 문자열이면 null로(= EKS default), 값 있으면 그 버전
  addon_ver = {
    for k, v in var.addon_versions : k => (v == "" ? null : v)
  }
}

# ── 공통 Add-on (dev/prod 둘 다) ──────────────────────────────────

# vpc-cni: Pod 네트워킹(ENI 할당). 없으면 Pod가 IP를 못 받음.
resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "vpc-cni"
  addon_version = lookup(local.addon_ver, "vpc_cni", null)

  # 충돌 시 EKS 관리값 우선(덮어쓰기). 최초 설치/업데이트 안정성.
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpc-cni" })

  depends_on = [aws_eks_cluster.main]
}

# coredns: 클러스터 내부 DNS.
# dev(Fargate)는 main.tf의 coredns Fargate profile이 먼저 있어야 함(없으면 Pending).
resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "coredns"
  addon_version = lookup(local.addon_ver, "coredns", null)

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(var.tags, { Name = "${var.name_prefix}-coredns" })

  # Fargate면 coredns profile 뜬 뒤 설치되도록
  depends_on = [
    aws_eks_cluster.main,
    aws_eks_fargate_profile.coredns,
  ]
}

# kube-proxy: 노드 네트워크 라우팅.
resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "kube-proxy"
  addon_version = lookup(local.addon_ver, "kube_proxy", null)

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(var.tags, { Name = "${var.name_prefix}-kube-proxy" })

  depends_on = [aws_eks_cluster.main]
}

# ── node_group(prod) 전용 Add-on ──────────────────────────────────

# eks-pod-identity-agent: Pod Identity의 노드 에이전트.
# Fargate 미지원(DaemonSet/privileged) → node_group만 (count로 토글).
resource "aws_eks_addon" "pod_identity_agent" {
  count = local.enable_node_only_addons ? 1 : 0

  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "eks-pod-identity-agent"
  addon_version = lookup(local.addon_ver, "pod_identity_agent", null)

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(var.tags, { Name = "${var.name_prefix}-pod-identity-agent" })

  depends_on = [aws_eks_cluster.main]
}

# aws-ebs-csi-driver: EBS 볼륨 PV.
# Fargate Pod엔 EBS 마운트 불가 + node DaemonSet은 EC2만 → node_group만.
# IAM은 IRSA(service_account_role_arn). managed addon은 Pod Identity 미지원.
# EBS CSI IRSA role은 eks-iam.tf에서 내부 생성(local.ebs_csi_role_arn).
resource "aws_eks_addon" "ebs_csi" {
  count = local.enable_node_only_addons ? 1 : 0

  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "aws-ebs-csi-driver"
  addon_version = lookup(local.addon_ver, "ebs_csi_driver", null)

  # IRSA role 주입 (있을 때만). 없으면 EBS 프로비저닝 시 권한 에러.
  service_account_role_arn = local.ebs_csi_role_arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(var.tags, { Name = "${var.name_prefix}-ebs-csi" })

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main, # 노드 떠야 EBS CSI node DaemonSet 동작
  ]
}
