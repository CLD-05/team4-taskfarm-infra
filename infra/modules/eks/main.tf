# ----------------------------------------------------------------------
# local 변수
# ----------------------------------------------------------------------
locals {
  enabled_node_group      = var.compute_type == "node_group"
  enabled_fargate_profile = var.compute_type == "fargate"
  enabled_pod_identity_s3 = var.compute_type == "node_group" && var.enabled_pod_identity_s3
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
# 클러스터 본체 (버전, 서브넷 연결, 인증 모드 API, 로깅 활성화)  ← 인증·로깅을 생성 시점에 함께
# ----------------------------------------------------------------------

resource "aws_eks_cluster" "main" {
  name = "${var.name_prefix}-eks"
  # EKS 컨트롤 플레인이 사용할 IAM Role
  role_arn = var.eks_cluster_role_arn
  version  = var.eks_cluster_version

  # 클러스터 인증 모드 API로 설정
  access_config {
    authentication_mode = "API"
  }

  # EKS 컨트롤 플레인 로깅 활성화
  # ["api", "audit", "authenticator"]
  enabled_cluster_log_types = var.enabled_cluster_log_types
  vpc_config {
    # EKS 컨트롤 플레인과 노드가 연결될 서브넷
    subnet_ids = var.private_subnet_ids

    # 클러스터 보안 그룹
    security_group_ids = [
      var.eks_cluster_sg_id
    ]

    # eks api를 통해 퍼블릭으로 접근하지 못하게 차단
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
# 노드그룹 (private 서브넷, 타입·수 변수화)
# ----------------------------------------------------------------------

resource "aws_launch_template" "eks_node" {
  count = local.enabled_node_group ? 1 : 0

  name_prefix = "${var.name_prefix}-node-lt-"

  # 노드 EC2에 붙일 Security Group
  vpc_security_group_ids = [
    var.eks_node_sg_id
  ]

  # 노드 루트 볼륨 설정
  block_device_mappings {
    # EC2 내부에서 디스크가 붙는 장치 위치
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.node_group_disk_size
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  # EC2 인스턴스에 붙을 태그
  tag_specifications {
    resource_type = "instance"

    tags = merge(var.tags, {
      Name = "${var.name_prefix}-eks-node"
    })
  }

  # EBS 볼륨에 붙을 태그
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

# EKS 노드 그룹
resource "aws_eks_node_group" "main" {
  count = local.enabled_node_group ? 1 : 0

  # 어느 클러스터에 붙을 노드그룹인지 지정
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.name_prefix}-node-group"
  # 워커 노드 EC2가 사용할 IAM Role
  node_role_arn = var.eks_node_role_arn
  # 노드가 생성될 서브넷
  subnet_ids = var.private_subnet_ids

  instance_types = var.node_group_instance_types

  launch_template {
    id      = aws_launch_template.eks_node[0].id
    version = "$Latest"
  }

  # 오토스케일링 설정
  scaling_config {
    desired_size = var.node_group_desired_size
    min_size     = var.node_group_min_size
    max_size     = var.node_group_max_size
  }

  # 노드 업데이트 시 한번에 하나씩 교체
  update_config {
    max_unavailable = 1
  }

  # 클러스터가 만들어진 뒤 노드그룹 생성
  depends_on = [aws_eks_cluster.main]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-node-group"
  })
}

# ----------------------------------------------------------------------
# Fargate Profile
# ----------------------------------------------------------------------

resource "aws_eks_fargate_profile" "app" {
  count = local.enabled_fargate_profile ? 1 : 0

  cluster_name         = aws_eks_cluster.main.name
  fargate_profile_name = "${var.name_prefix}-app-fargate-profile"
  # EKS Fargate 인프라가 Pod를 실행하고, kubelet이 클러스터에 등록되기 위해 쓰는 Role
  pod_execution_role_arn = var.fargate_pod_execution_role_arn
  subnet_ids             = var.private_subnet_ids

  # var.namespace에 생성되는 Pod들은 Fargate로 실행
  selector {
    namespace = var.namespace
  }

  depends_on = [aws_eks_cluster.main]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-app-fargate-profile"
  })

}

# ----------------------------------------------------------------------
# CoreDNS용 => 쿠버네티스 내부 DNS
# ----------------------------------------------------------------------

resource "aws_eks_fargate_profile" "coredns" {
  count = local.enabled_fargate_profile ? 1 : 0

  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "${var.name_prefix}-coredns-fargate-profile"
  pod_execution_role_arn = var.fargate_pod_execution_role_arn
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
# Access Entry = kubectl로 클러스터에 접근할 수 있게 IAM Role 등록 설정
# ----------------------------------------------------------------------

# Access Entry 생성 => 지정된 IAM 역할이 EKS 클러스터에 접근할 수 있도록 등록
resource "aws_eks_access_entry" "cluster_admin" {
  cluster_name = aws_eks_cluster.main.name
  # kubectl 관리자 권한을 줄 IAM Role ARN
  principal_arn = var.admin_iam_role_arn
  type          = "STANDARD"

  depends_on = [aws_eks_cluster.main]

  # 버전에 따라 안될 수 있음 => terraform validate로 확인!
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cluster-admin-access-entry"
  })
}

# 클러스터 관리자 권한 부여
resource "aws_eks_access_policy_association" "cluster_admin_policy" {
  cluster_name = aws_eks_cluster.main.name
  # Access Entry와 같은 IAM Role ARN
  principal_arn = var.admin_iam_role_arn
  # EKS 클러스터 관리자 권한
  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    # 권한 범위를 클러스터로 제한
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.cluster_admin]
}

# ----------------------------------------------------------------------
# Pod Identity IAM Role = Pod가 AWS 리소스에 접근할 떄 사용할 IAM Role
# ----------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# 내 AWS 계정의 team4 클러스터에서 온 Pod Identity 요청만 Role 사용 가능
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
          # 내 AWS 계정에서 온 요청만 허용
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnEquals = {
          # 이 EKS 클러스터에서 온 요청만 허용 (Pod가 S3 접근을 못하면 지워서 해보기)
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
          Sid    = "AllowListBucket"
          Effect = "Allow"
          # 버킷 목록 조회 권한
          Action = [
            "s3:ListBucket"
          ]
          Resource = var.s3_bucket_arn
        }
      ],
      [
        {
          Sid    = "AllowObjectAccess"
          Effect = "Allow"
          # 객체 접근 권한
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

# 위에서 만든 IAM Role에 S3 최소 권한 정책 붙이는 것
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

  cluster_name = aws_eks_cluster.main.name
  # 권한을 줄 Kubernetes namespace
  namespace = var.namespace
  # 권한을 줄 Kubernetes serviceAccount
  service_account = var.service_account
  # Pod에 연결할 IAM Role
  role_arn = aws_iam_role.pod_identity_role[0].arn

  depends_on = [
    aws_iam_role_policy_attachment.pod_identity_s3_policy_attachment
  ]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-pod-identity-association"
  })
}
