data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(sort(data.aws_availability_zones.available.names), 0, 2)

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

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-public-${each.key}"
  })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(var.tags, { Name = "${var.name_prefix}-private-${each.key}"
  })
}

resource "aws_subnet" "db" {
  for_each = local.db_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(var.tags, { Name = "${var.name_prefix}-db-${each.key}"
  })
}

resource "aws_eip" "nat" {
  for_each = var.env == "prod" ? local.public_subnets : {}

  domain = "vpc"
  tags = merge(var.tags, { Name = "${var.name_prefix}-nat-eip-${each.key}"
  })
}

resource "aws_nat_gateway" "nat" {
  for_each = var.env == "prod" ? local.public_subnets : {}

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
  tags = merge(var.tags, { Name = "${var.name_prefix}-nat-${each.key}"
  })

  depends_on = [aws_internet_gateway.this]
}

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

resource "aws_eip" "nat_instance" {
  count = var.env == "dev" ? 1 : 0

  domain   = "vpc"
  instance = aws_instance.nat[0].id
  tags     = merge(var.tags, { Name = "${var.name_prefix}-nat-instance-eip" })
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

resource "aws_route_table" "db" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-db-rt" })
}

resource "aws_route_table_association" "db" {
  for_each = aws_subnet.db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.db.id
}

resource "aws_route_table" "private" {
  for_each = local.private_subnets

  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-private-rt-${each.key}" })

}

resource "aws_route" "private_nat_instance" {
  for_each = var.env == "dev" ? local.private_subnets : {}

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat[0].primary_network_interface_id
}

# prod: private → NAT Gateway (같은 AZ)
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

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = [for s in aws_subnet.db : s.id]
  tags       = merge(var.tags, { Name = "${var.name_prefix}-db-subnet-group" })
}

