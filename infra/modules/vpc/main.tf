# modules/vpc/main.tf

# ── [FIX-1] AZ 자동조회 제거 → 변수로 명시 ──
# (원본)
# data "aws_availability_zones" "available" {
#   state = "available"
# }
#
# locals {
#   azs = slice(sort(data.aws_availability_zones.available.names), 0, 2)
#   ...
# }
# 문제: sort 하면 2a,2b 선택됨. 2b는 서울 구형 AZ라 a,c 써야 함(강사 지침).
#       자동조회는 의도(어느 AZ를 쓰는지)가 코드에 안 드러나는 단점도 있음.
# 해결: var.azs 로 ["ap-northeast-2a","ap-northeast-2c"] 명시 주입.

locals {
  # var.azs 순서대로 서브넷 CIDR 매핑 (인덱스 = AZ 순서)
  azs = var.azs

  public_subnets  = { for i, cidr in var.public_subnet_cidrs : local.azs[i] => cidr }
  private_subnets = { for i, cidr in var.private_subnet_cidrs : local.azs[i] => cidr }
  db_subnets      = { for i, cidr in var.db_subnet_cidrs : local.azs[i] => cidr }

  # [FIX-2] dev NAT는 1개만. dev에선 첫 번째 AZ(2a)에만 NAT Instance를 두고
  #         모든 private이 그걸 바라보게 함. prod는 AZ별 NAT Gateway(아래 for_each).
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

# ── 서브넷 (— for_each 매핑 그대로 유지) ──
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true

  # [ADD] EKS/ALB가 서브넷 자동발견에 쓰는 태그. 없으면 ALB Controller가
  #       어느 서브넷에 ALB를 둘지 못 찾음. 퍼블릭=elb.
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

  # [ADD] private=internal-elb. EKS 노드/내부 LB 배치용 자동발견 태그.
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

# ── PROD: AZ별 NAT Gateway (원본 유지) ──
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

# ── DEV: NAT Instance (fck-nat, t4g.nano) — 원본 유지 ──
# fck-nat AMI(arm64) + t4g.nano + source_dest_check=false 까지 정확
data "aws_ami" "nat" {
  count       = var.env == "dev" ? 1 : 0
  most_recent = true
  owners      = ["568608671756"]

  filter {
    name   = "name"
    values = ["fck-nat-amzn-*"]
  }
  filter {
    name   = "architecture"
    values = ["arm64"] # t4g = ARM
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
  subnet_id              = values(aws_subnet.public)[0].id # 2a public에 배치
  source_dest_check      = false                           # NAT는 자기 외 트래픽 통과 → 필수
  vpc_security_group_ids = [aws_security_group.nat[0].id]
  tags                   = merge(var.tags, { Name = "${var.name_prefix}-nat-instance" })
}

resource "aws_eip" "nat_instance" {
  count = var.env == "dev" ? 1 : 0

  domain   = "vpc"
  instance = aws_instance.nat[0].id
  tags     = merge(var.tags, { Name = "${var.name_prefix}-nat-instance-eip" })
}

# ── 퍼블릭 라우트 (원본 유지) ──
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

# ── DB 라우트 (인터넷 경로 없음 = 격리.) ──
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-db-rt" })
}

resource "aws_route_table_association" "db" {
  for_each = aws_subnet.db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.db.id
}

# ── 프라이빗 라우트 (AZ별 라우트테이블 — 원본 유지) ──
resource "aws_route_table" "private" {
  for_each = local.private_subnets

  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-private-rt-${each.key}" })
}

# dev: 모든 private → 단일 NAT Instance (원본 유지)
resource "aws_route" "private_nat_instance" {
  for_each = var.env == "dev" ? local.private_subnets : {}

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat[0].primary_network_interface_id
}

# prod: private → 같은 AZ NAT Gateway (원본 유지)
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
