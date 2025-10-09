# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "xelta-${var.environment}-vpc-${var.region}"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "xelta-${var.environment}-igw-${var.region}"
    Environment = var.environment
  }
}

# Public Subnets (3 AZs)
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                                      = "xelta-${var.environment}-public-${var.availability_zones[count.index]}"
    Environment                                               = var.environment
    "kubernetes.io/role/elb"                                  = "1"
    "kubernetes.io/cluster/xelta-${var.environment}-eks-${var.region}" = "shared"
  }
}

# Private Subnets (3 AZs)
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 3)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                                                      = "xelta-${var.environment}-private-${var.availability_zones[count.index]}"
    Environment                                               = var.environment
    "kubernetes.io/role/internal-elb"                         = "1"
    "kubernetes.io/cluster/xelta-${var.environment}-eks-${var.region}" = "shared"
  }
}

# Database Subnets (3 AZs)
resource "aws_subnet" "database" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 6)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "xelta-${var.environment}-database-${var.availability_zones[count.index]}"
    Environment = var.environment
    Tier        = "database"
  }
}

# Elastic IPs for NAT Gateways
# Trade-off: One NAT per AZ = HA but higher cost (~$32/month per NAT)
# Alternative: Single NAT = lower cost but single point of failure
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  domain = "vpc"

  tags = {
    Name        = "xelta-${var.environment}-nat-eip-${count.index + 1}-${var.region}"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "xelta-${var.environment}-nat-${count.index + 1}-${var.region}"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "xelta-${var.environment}-public-rt-${var.region}"
    Environment = var.environment
  }
}

# Public Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables (one per AZ for independent NAT routing)
resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name        = "xelta-${var.environment}-private-rt-${var.availability_zones[count.index]}"
    Environment = var.environment
  }
}

# Private Route Table Associations
resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Database Route Table
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "xelta-${var.environment}-database-rt-${var.region}"
    Environment = var.environment
  }
}

# Database Route Table Associations
resource "aws_route_table_association" "database" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

# VPC Flow Logs (security best practice)
resource "aws_flow_log" "main" {
  vpc_id         = aws_vpc.main.id
  traffic_type   = "ALL"
  iam_role_arn   = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn

  tags = {
    Name        = "xelta-${var.environment}-flow-log-${var.region}"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc/xelta-${var.environment}-${var.region}"
  retention_in_days = 7

  tags = {
    Name        = "xelta-${var.environment}-flow-log-${var.region}"
    Environment = var.environment
  }
}

resource "aws_iam_role" "flow_log" {
  name = "xelta-${var.environment}-vpc-flow-log-${var.region}"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "flow_log" {
  name = "xelta-${var.environment}-vpc-flow-log-policy-${var.region}"
  role = aws_iam_role.flow_log.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}