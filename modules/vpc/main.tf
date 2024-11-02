# Create VPC
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  tags = merge({
    "Name" = var.vpc_name,
  }, var.tags)
}

# Create Public Subnets
resource "aws_subnet" "public" {
  count = length(var.azs)

  availability_zone       = var.azs[count.index]
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.this.id

  tags = merge({
    "Name" = "${var.public_subnet_name}-${count.index}"
  }, var.tags)
}

# Create Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge({
    "Name" = var.igw_name
  }, var.tags)
}

# Create Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge({
    "Name" = var.public_route_table_name
  }, var.tags)
}

# Associate Public Subnets with Route Table
resource "aws_route_table_association" "public" {
  count = length(var.azs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Create Private Subnets
resource "aws_subnet" "private" {
  count = length(var.azs)

  availability_zone       = var.azs[count.index]
  cidr_block              = var.private_subnet_cidrs[count.index]
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.this.id

  tags = merge({
    "Name" = "${var.private_subnet_name}-${count.index}"
  }, var.tags)
}

# Create NAT Gateways (if required)
resource "aws_eip" "nat" {
  count      = var.create_nat_gateway ? length(var.azs) : 0
  vpc        = true
  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = var.create_nat_gateway ? length(var.azs) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge({
    "Name" = "${var.vpc_name}-nat-gateway-${count.index}"
  }, var.tags)
}

# Create Private Route Tables
resource "aws_route_table" "private" {
  count = length(var.azs)

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = merge({
    "Name" = "${var.vpc_name}-private-rt-${count.index}"
  }, var.tags)
}

# Associate Private Subnets with Route Tables
resource "aws_route_table_association" "private" {
  count = length(var.azs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

