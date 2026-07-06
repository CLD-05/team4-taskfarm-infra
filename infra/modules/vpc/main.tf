# modules/vpc/main.tf

# [ADD] SSM 엔드포인트 service_name에 쓸 현재 리전 자동 조회 (var.region 없이)
data "aws_region" "current" {}

# ── [FIX-1] AZ 자동조회 제거 → 변수로 명시 ──
locals {
  # var.azs 순서대로 서브넷 CIDR 매핑 (인덱스 = AZ 순서)
  azs = var.azs

  public_subnets  = { for i, cidr in var.public_subnet_cidrs : local.azs[i] => cidr }
  private_subnets = { for i, cidr in var.private_subnet_cidrs : local.azs[i] => cidr }
  db_subnets      = { for i, cidr in var.db_subnet_cidrs : local.azs[i] => cidr }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

# ── 서브넷 ──
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                     = "${var.name_prefix}-public-${each.key}"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(var.tags, {
    Name                              = "${var.name_prefix}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_subnet" "db" {
  for_each = local.db_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(var.tags, { Name = "${var.name_prefix}-db-${each.key}" })
}

# ── PROD: AZ별 NAT Gateway ──
resource "aws_eip" "nat" {
  for_each = var.env == "prod" ? local.public_subnets : {}

  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-nat-eip-${each.key}" })
}

resource "aws_nat_gateway" "nat" {
  for_each = var.env == "prod" ? local.public_subnets : {}

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
  tags          = merge(var.tags, { Name = "${var.name_prefix}-nat-${each.key}" })

  depends_on = [aws_internet_gateway.this]
}

# ── DEV: NAT Instance (fck-nat, t4g.nano) ──
data "aws_ami" "nat" {
  count       = var.env == "dev" ? 1 : 0
  most_recent = true
  owners      = ["568608671756"]

  filter {
    name   = "name"
    values = ["fck-nat-al2023-*"]
  }
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

resource "aws_security_group" "nat" {
  count  = var.env == "dev" ? 1 : 0
  name   = "${var.name_prefix}-nat-sg"
  vpc_id = aws_vpc.this.id

  ingress {
    description = "from private subnets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = values(local.private_subnets)
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-nat-sg" })
}

resource "aws_instance" "nat" {
  count = var.env == "dev" ? 1 : 0

  ami                    = data.aws_ami.nat[0].id
  instance_type          = "t4g.nano"
  subnet_id              = values(aws_subnet.public)[0].id
  source_dest_check      = false
  vpc_security_group_ids = [aws_security_group.nat[0].id]
  tags                   = merge(var.tags, { Name = "${var.name_prefix}-nat-instance" })
}

resource "aws_eip" "nat_instance" {
  count = var.env == "dev" ? 1 : 0

  domain   = "vpc"
  instance = aws_instance.nat[0].id
  tags     = merge(var.tags, { Name = "${var.name_prefix}-nat-instance-eip" })
}

# ── 퍼블릭 라우트 ──
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ── DB 라우트 (인터넷 경로 없음 = 격리) ──
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-db-rt" })
}

resource "aws_route_table_association" "db" {
  for_each = aws_subnet.db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.db.id
}

# ── 프라이빗 라우트 (AZ별 라우트테이블) ──
resource "aws_route_table" "private" {
  for_each = local.private_subnets

  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-private-rt-${each.key}" })
}

# dev: 모든 private → 단일 NAT Instance
resource "aws_route" "private_nat_instance" {
  for_each = var.env == "dev" ? local.private_subnets : {}

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat[0].primary_network_interface_id
}

# prod: private → 같은 AZ NAT Gateway
resource "aws_route" "private_nat_gateway" {
  for_each = var.env == "prod" ? local.private_subnets : {}

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[each.key].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# ── DB 서브넷 그룹 (RDS용) ──
resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = [for s in aws_subnet.db : s.id]
  tags       = merge(var.tags, { Name = "${var.name_prefix}-db-subnet-group" })
}

# ==========================================================
# SSM VPC Endpoints (bastion SSM 접속용 — prod만)
#   Private 서브넷 bastion이 인터넷 경유 없이 SSM 연결
#   ssm / ssmmessages / ec2messages 3종 필수
#   [설계 원복] 원래 아키텍처에 있었으나 누락됐던 부분 복구
# ==========================================================
resource "aws_security_group" "ssm_endpoint" {
  count       = var.env == "prod" ? 1 : 0
  name        = "${var.name_prefix}-ssm-endpoint-sg"
  description = "Allow HTTPS from VPC for SSM interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ssm-endpoint-sg"
  })
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = var.env == "prod" ? toset(["ssm", "ssmmessages", "ec2messages"]) : toset([])

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.ssm_endpoint[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${each.value}-endpoint"
  })
}
