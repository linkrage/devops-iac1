# Packer support resources - ensure default VPC has subnet and IGW
# Safe checks for idempotency

data "aws_vpc" "default" {
  default = true
}

# Check for existing IGW in default VPC
data "external" "igw_check" {
  count = local.check_existing ? 1 : 0

  program = [
    "bash", "-c",
    "vpc_id=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --region ${var.aws_region} --query 'Vpcs[0].VpcId' --output text 2>/dev/null); igw_id=$(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$vpc_id --region ${var.aws_region} --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null || echo ''); if [ -n \"$igw_id\" ]; then echo '{\"exists\":\"true\",\"id\":\"$igw_id\"}'; else echo '{\"exists\":\"false\"}'; fi"
  ]
}

# Check for existing subnet for Packer
data "aws_subnets" "packer_existing" {
  count = local.manage_bootstrap_resources ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "tag:Purpose"
    values = ["packer-builds"]
  }
}

locals {
  existing_default_vpc_igw    = local.check_existing ? try(data.external.igw_check[0].result.exists == "true" ? data.external.igw_check[0].result.id : "", "") : ""
  existing_packer_subnets     = try(data.aws_subnets.packer_existing[0].ids, [])

  create_default_vpc_igw      = local.manage_bootstrap_resources && local.existing_default_vpc_igw == ""
  create_packer_subnet        = local.manage_bootstrap_resources && length(local.existing_packer_subnets) == 0
}

# Create IGW for default VPC (only if doesn't exist)
resource "aws_internet_gateway" "default_vpc" {
  count = local.create_default_vpc_igw ? 1 : 0

  vpc_id = data.aws_vpc.default.id

  tags = merge(local.base_tags, {
    Name    = "default-vpc-igw"
    Purpose = "packer-builds"
  })
}

# Create a subnet in the default VPC for Packer builds (only if doesn't exist)
resource "aws_subnet" "packer_default" {
  count = local.create_packer_subnet ? 1 : 0

  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.0.0/20"  # Standard default VPC subnet size
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(local.base_tags, {
    Name    = "default-vpc-subnet-${var.aws_region}a"
    Purpose = "packer-builds"
  })
}

# Get main route table
data "aws_route_table" "default_vpc_main" {
  vpc_id = data.aws_vpc.default.id

  filter {
    name   = "association.main"
    values = ["true"]
  }
}

# Check if internet route already exists
data "aws_route" "default_vpc_internet_existing" {
  count = local.manage_bootstrap_resources ? 1 : 0

  route_table_id         = data.aws_route_table.default_vpc_main.id
  destination_cidr_block = "0.0.0.0/0"
}

locals {
  default_vpc_needs_route = local.manage_bootstrap_resources && try(data.aws_route.default_vpc_internet_existing[0].gateway_id, "") == ""
}

# Ensure internet route exists (only create if doesn't exist)
resource "aws_route" "default_vpc_internet" {
  count = local.default_vpc_needs_route ? 1 : 0

  route_table_id         = data.aws_route_table.default_vpc_main.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = local.create_default_vpc_igw ? aws_internet_gateway.default_vpc[0].id : local.existing_default_vpc_igw
}