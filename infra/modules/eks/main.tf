# modules/eks/main.tf

# ----------------------------------------------------------------------
# local 변수
# ----------------------------------------------------------------------
locals {
  enabled_node_group      = var.compute_type == "node_group"
  enabled_fargate_profile = var.compute_type == "fargate"

  # [FIX-1] enabled_pod_identity_s3 → enable_pod_identity_s3 (d 없음, variables.tf와 통일)
  # ⚠️ Fargate는 eks-pod-identity-agent 미지원(DaemonSet/privileged) → node_group일 때만.
  enabled_pod_identity_s3 = var.compute_type == "node_group" && var.enable_pod_identity_s3
}

# ----------------------------------------------------------------------
# CloudWatch 로그 그룹 생성
# ----------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "eks" {
  name = "/aws/eks/${var.name_prefix}-eks/cluster"
  # 로그를 30일만 보관
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-log-group"
  })
}

# ----------------------------------------------------------------------
# 클러스터 본체 (버전, 서브넷 연결, 인증 모드 API, 로깅 활성화)
# ----------------------------------------------------------------------
resource "aws_eks_cluster" "main" {
  name = "${var.name_prefix}-eks"
  # EKS 컨트롤 플레인이 사용할 IAM Role
  role_arn = local.cluster_role_arn
  version  = var.eks_cluster_version

  # 클러스터 인증 모드 API로 설정
  access_config {
    authentication_mode = "API"
  }

  # EKS 컨트롤 플레인 로깅 활성화
  enabled_cluster_log_types = var.enabled_cluster_log_types

  vpc_config {
    # EKS 컨트롤 플레인과 노드가 연결될 서브넷
    subnet_ids = var.private_subnet_ids

    # 클러스터 보안 그룹
    security_group_ids = [
      local.cluster_sg_id
    ]

    # eks api 퍼블릭/프라이빗 접근 제어
    endpoint_public_access  = var.endpoint_public_access
    endpoint_private_access = var.endpoint_private_access
    public_access_cidrs     = var.public_access_cidrs
  }

  # 로그 그룹을 먼저 만든 뒤 클러스터를 생성하도록 강제
  depends_on = [aws_cloudwatch_log_group.eks]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks"
  })
}

# ----------------------------------------------------------------------
# [ADD-1] IRSA용 OIDC Provider
# ----------------------------------------------------------------------
# platform-addons(ALB Controller, ESO, ExternalDNS)가 IRSA로 IAM 권한을 받으려면
# 클러스터의 OIDC issuer가 IAM에 OIDC provider로 등록돼 있어야 합니다.
# 이게 없으면 그 addon들의 IRSA role trust가 성립 안 돼 권한을 못 받습니다.
data "tls_certificate" "oidc" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-oidc"
  })
}

# ----------------------------------------------------------------------
# 노드그룹 (private 서브넷, 타입·수 변수화) — node_group(prod)만
# ----------------------------------------------------------------------
resource "aws_launch_template" "eks_node" {
  count = local.enabled_node_group ? 1 : 0

  name_prefix = "${var.name_prefix}-node-lt-"

  # 노드 EC2에 붙일 Security Group
  vpc_security_group_ids = [
    local.node_sg_id
  ]

  # 노드 루트 볼륨 설정 (gp3 + 암호화)
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.node_group_disk_size
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-eks-node"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-eks-node-volume"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-node-lt"
  })
}

resource "aws_eks_node_group" "main" {
  count = local.enabled_node_group ? 1 : 0

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.name_prefix}-node-group"
  node_role_arn   = local.node_role_arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.node_group_instance_types

  launch_template {
    id      = aws_launch_template.eks_node[0].id
    version = "$Latest"
  }

  scaling_config {
    desired_size = var.node_group_desired_size
    min_size     = var.node_group_min_size
    max_size     = var.node_group_max_size
  }

  # 노드 업데이트 시 한번에 하나씩 교체
  update_config {
    max_unavailable = 1
  }

  depends_on = [aws_eks_cluster.main]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-node-group"
  })
}

# ----------------------------------------------------------------------
# Fargate Profile (앱) — fargate(dev)만
# ----------------------------------------------------------------------
resource "aws_eks_fargate_profile" "app" {
  count = local.enabled_fargate_profile ? 1 : 0

  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.name_prefix}-app-fargate-profile"
  pod_execution_role_arn = local.fargate_role_arn
  subnet_ids             = var.private_subnet_ids

  selector {
    namespace = var.namespace
  }

  depends_on = [aws_eks_cluster.main]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-app-fargate-profile"
  })
}

# ----------------------------------------------------------------------
# CoreDNS용 Fargate Profile — fargate(dev)만
# (dev에서 CoreDNS가 Fargate로 뜨려면 이게 꼭 필요.)
# ----------------------------------------------------------------------
resource "aws_eks_fargate_profile" "coredns" {
  count = local.enabled_fargate_profile ? 1 : 0

  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.name_prefix}-coredns-fargate-profile"
  pod_execution_role_arn = local.fargate_role_arn
  subnet_ids             = var.private_subnet_ids

  selector {
    namespace = "kube-system"
    labels = {
      "k8s-app" = "kube-dns"
    }
  }

  depends_on = [aws_eks_cluster.main]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-coredns-fargate-profile"
  })
}

# ----------------------------------------------------------------------
# Access Entry = kubectl로 클러스터 접근할 IAM Role 등록
# ----------------------------------------------------------------------
resource "aws_eks_access_entry" "cluster_admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.admin_iam_role_arn
  type          = "STANDARD"

  depends_on = [aws_eks_cluster.main]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cluster-admin-access-entry"
  })
}

resource "aws_eks_access_policy_association" "cluster_admin_policy" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.admin_iam_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.cluster_admin]
}

# [NOTE] bastion role도 kubectl 권한 주려면 위와 같은 access_entry를 하나 더 만들거나,
#        admin_iam_role_arn에 bastion role을 줄 수 있습니다. (bastion 모듈의 iam_role_arn output 사용)
#        여러 principal이면 for_each로 access_entry를 묶는 것도 방법입니다.

# ----------------------------------------------------------------------
# Pod Identity IAM Role = Pod가 AWS 리소스 접근 시 쓸 Role
# (node_group + enable_pod_identity_s3 일 때만)
# ----------------------------------------------------------------------
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "pod_identity_role" {
  count = local.enabled_pod_identity_s3 ? 1 : 0

  name = "${var.name_prefix}-eks-pod-identity-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        # EKS Pod Identity 서비스가 이 IAM Role을 빌릴 수 있다.
        Service = "pods.eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnEquals = {
          "aws:SourceArn" = aws_eks_cluster.main.arn
        }
      }
    }]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-eks-pod-identity-role"
  })
}

# ----------------------------------------------------------------------
# Pod Identity용 S3 최소 권한 정책
# ----------------------------------------------------------------------
resource "aws_iam_policy" "pod_identity_s3_policy" {
  count = local.enabled_pod_identity_s3 ? 1 : 0

  name = "${var.name_prefix}-pod-identity-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid      = "AllowListBucket"
          Effect   = "Allow"
          Action   = ["s3:ListBucket"]
          Resource = var.s3_bucket_arn
        }
      ],
      [
        {
          Sid      = "AllowObjectAccess"
          Effect   = "Allow"
          Action   = var.s3_object_actions
          Resource = "${var.s3_bucket_arn}/*"
        }
      ]
    )
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-pod-identity-s3-policy"
  })
}

resource "aws_iam_role_policy_attachment" "pod_identity_s3_policy_attachment" {
  count = local.enabled_pod_identity_s3 ? 1 : 0

  role       = aws_iam_role.pod_identity_role[0].name
  policy_arn = aws_iam_policy.pod_identity_s3_policy[0].arn
}

# ----------------------------------------------------------------------
# Pod Identity Association
# ----------------------------------------------------------------------
resource "aws_eks_pod_identity_association" "main" {
  count = local.enabled_pod_identity_s3 ? 1 : 0

  cluster_name    = aws_eks_cluster.main.name
  namespace       = var.namespace
  service_account = var.service_account
  role_arn        = aws_iam_role.pod_identity_role[0].arn

  depends_on = [
    aws_iam_role_policy_attachment.pod_identity_s3_policy_attachment
  ]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-pod-identity-association"
  })
}
