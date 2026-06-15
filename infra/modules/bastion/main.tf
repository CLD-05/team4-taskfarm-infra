locals {
  enabled = var.enabled ? 1 : 0
  name    = "team4-${var.env}-bastion"
}

data "aws_ami" "al2023" {
  count       = var.ami_id == "" && var.enabled ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : try(data.aws_ami.al2023[0].id, "")
}


# SSM IAM
resource "aws_iam_role" "this" {
  count = local.enabled
  name  = "${local.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${local.name}-role" })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  count      = local.enabled
  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "eks_describe" {
  count = local.enabled
  name  = "${local.name}-eks-describe"
  role  = aws_iam_role.this[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "this" {
  count = local.enabled
  name  = "${local.name}-profile"
  role  = aws_iam_role.this[0].name
  tags  = merge(var.tags, { Name = "${local.name}-profile" })
}


#SG
resource "aws_security_group" "this" {
  count       = local.enabled
  name        = "${local.name}-sg"
  description = "Bastion SG - no inbound (SSM only), all outbound"
  vpc_id      = var.vpc_id

  egress {
    description = "All outbound (SSM, package install, EKS/RDS access)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${local.name}-sg" })
}


#Instance
resource "aws_instance" "this" {
  count                  = local.enabled
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_id
  iam_instance_profile   = aws_iam_instance_profile.this[0].name
  vpc_security_group_ids = [aws_security_group.this[0].id]

  associate_public_ip_address = false

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # SSM Agent는 AL2023에 기본 설치돼 있지만, 명시적으로 활성화
    systemctl enable --now amazon-ssm-agent

    # aws-cli v2 (AL2023엔 보통 기본 포함, 없으면 설치)
    command -v aws >/dev/null 2>&1 || dnf install -y awscli

    # kubectl (EKS 관리) — amd64. ARM이면 .../linux/arm64/kubectl 로 변경
    curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl

    # helm (애드온 디버깅·수동조작용 CLI). 버전 고정 권장:
    #   curl ... | DESIRED_VERSION=v3.16.2 bash
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # mysql 클라이언트 (RDS 접근)
    dnf install -y mariadb105

    # 편의: 모든 유저에 도구 PATH 보장
    echo 'export PATH=$PATH:/usr/local/bin' >> /etc/profile.d/tools.sh
  EOF

  user_data_replace_on_change = true

  tags = merge(var.tags, { Name = local.name })
}
