# AZ 동적 선택 (letter 하드코딩 금지)
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # 사용 가능한 AZ 중 앞에서 az_count개 선택
  azs        = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  az_indexed = { for idx, az in local.azs : az => idx }

  # vpc_cidr(/16)에서 서브넷 CIDR 자동 분할 (겹침 방지: private=저대역, public/db=고대역)
  #   private /20 = newbits 4 -> 10.N.0.0/20, 10.N.16.0/20 ...
  #   public  /24 = newbits 8, offset 192 -> 10.N.192.0/24 ...
  #   db      /24 = newbits 8, offset 224 -> 10.N.224.0/24 ...
  private_subnets = { for az, idx in local.az_indexed : az => cidrsubnet(var.vpc_cidr, 4, idx) }
  public_subnets  = { for az, idx in local.az_indexed : az => cidrsubnet(var.vpc_cidr, 8, 192 + idx) }
  db_subnets      = { for az, idx in local.az_indexed : az => cidrsubnet(var.vpc_cidr, 8, 224 + idx) }

  # NAT 대상 AZ: single이면 첫 AZ에만, 아니면 전체 AZ
  nat_azs = var.single_nat_gateway ? [local.azs[0]] : local.azs
  nat_map = var.enable_nat_gateway ? { for az in local.nat_azs : az => az } : {}

  # 프라이빗 서브넷이 바라볼 NAT의 AZ 키 (single이면 모두 첫 NAT을 공유)
  private_nat_key = { for az in keys(local.private_subnets) : az => (var.single_nat_gateway ? local.azs[0] : az) }

  # EKS 클러스터 태그 (이름 지정 시에만)
  eks_cluster_tag = var.eks_cluster_name != "" ? { "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared" } : {}
}

############################
# VPC / Internet Gateway
############################
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-igw" })
}

############################
# Subnets (public / private / db) — AZ별 for_each
############################
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    local.eks_cluster_tag,
    {
      Name                     = "${var.name}-public-${each.key}"
      Tier                     = "public"
      "kubernetes.io/role/elb" = "1"
    }
  )
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge(
    var.tags,
    local.eks_cluster_tag,
    {
      Name                              = "${var.name}-private-${each.key}"
      Tier                              = "private"
      "kubernetes.io/role/internal-elb" = "1"
    }
  )
}

resource "aws_subnet" "db" {
  for_each = local.db_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge(var.tags, {
    Name = "${var.name}-db-${each.key}"
    Tier = "db"
  })
}

############################
# NAT Gateway (+ EIP) — dev 1개 / prod AZ별
############################
resource "aws_eip" "nat" {
  for_each = local.nat_map

  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.name}-nat-eip-${each.key}" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = local.nat_map

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(var.tags, { Name = "${var.name}-nat-${each.key}" })

  depends_on = [aws_internet_gateway.this]
}

############################
# Route Tables
############################
# 퍼블릭: 단일 RT → IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-public-rt" })
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

# 프라이빗: AZ별 RT → (해당/공유) NAT
resource "aws_route_table" "private" {
  for_each = local.private_subnets

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-private-rt-${each.key}" })
}

resource "aws_route" "private_nat" {
  for_each = var.enable_nat_gateway ? local.private_subnets : {}

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[local.private_nat_key[each.key]].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# DB: 단일 RT, 인터넷 라우트 없음(격리). VPC 내부 통신만 허용
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-db-rt" })
}

resource "aws_route_table_association" "db" {
  for_each = aws_subnet.db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.db.id
}

############################
# RDS 서브넷 그룹 (DB 서브넷 기반)
############################
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnet-group"
  subnet_ids = [for s in aws_subnet.db : s.id]

  tags = merge(var.tags, { Name = "${var.name}-db-subnet-group" })
}
