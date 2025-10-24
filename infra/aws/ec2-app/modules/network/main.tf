locals {
  public           = { for subnet in var.public_subnets : subnet.name => subnet }
  private          = { for subnet in var.private_subnets : subnet.name => subnet }
  public_az_lookup = { for key, subnet in local.public : subnet.az => key }
  cluster_tag_key  = var.eks_cluster_name != null && var.eks_cluster_name != "" ? "kubernetes.io/cluster/${var.eks_cluster_name}" : null
  subnet_cluster_tags = local.cluster_tag_key != null ? {
    (local.cluster_tag_key) = "shared"
  } : {}
  public_k8s_tags  = local.cluster_tag_key != null ? merge(local.subnet_cluster_tags, { "kubernetes.io/role/elb" = "1" }) : {}
  private_k8s_tags = local.cluster_tag_key != null ? merge(local.subnet_cluster_tags, { "kubernetes.io/role/internal-elb" = "1" }) : {}
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  for_each                = local.public
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(var.tags, local.public_k8s_tags, {
    Name = each.value.name
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  for_each                = local.private
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = merge(var.tags, local.private_k8s_tags, {
    Name = each.value.name
    Tier = "private"
  })
}

resource "aws_eip" "nat" {
  for_each = local.public
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${each.value.name}-eip"
  })
}

resource "aws_nat_gateway" "this" {
  for_each          = local.public
  allocation_id     = aws_eip.nat[each.key].id
  subnet_id         = aws_subnet.public[each.key].id
  connectivity_type = "public"

  depends_on = [aws_internet_gateway.this]

  tags = merge(var.tags, {
    Name = "${each.value.name}-nat"
  })
}

resource "aws_route_table" "public" {
  for_each = local.public
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${each.value.name}-rt"
    Tier = "public"
  })
}

resource "aws_route_table_association" "public" {
  for_each       = local.public
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[each.key].id
}

resource "aws_route_table" "private" {
  for_each = local.private
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[lookup(local.public_az_lookup, each.value.az, keys(local.public)[0])].id
  }

  tags = merge(var.tags, {
    Name = "${each.value.name}-rt"
    Tier = "private"
  })
}

resource "aws_route_table_association" "private" {
  for_each       = local.private
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_security_group" "endpoints" {
  name        = "${var.name_prefix}-vpce"
  description = "Allow VPC interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Interface endpoint from VPC"
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
    Name = "${var.name_prefix}-vpce-sg"
  })
}

locals {
  interface_services = [
    "ssm",
    "ssmmessages",
    "ec2messages"
  ]
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(local.interface_services)
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.endpoints.id]
  subnet_ids          = [for subnet in aws_subnet.private : subnet.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${each.key}-vpce"
  })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.private : rt.id]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-s3-vpce"
  })
}
