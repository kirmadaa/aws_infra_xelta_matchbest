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
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway && !var.enable_ec2_nat_instance ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  domain = "vpc"

  tags = {
    Name        = "xelta-${var.environment}-nat-eip-${count.index + 1}-${var.region}"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway && !var.enable_ec2_nat_instance ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "xelta-${var.environment}-nat-${count.index + 1}-${var.region}"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

# --- EC2 NAT INSTANCE (COST SAVING) ---
data "aws_ami" "amazon_linux_2_arm" {
  count = var.enable_nat_gateway && var.enable_ec2_nat_instance ? 1 : 0

  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-arm64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "nat_instance" {
  count       = var.enable_nat_gateway && var.enable_ec2_nat_instance ? 1 : 0
  name        = "xelta-${var.environment}-nat-instance-${var.region}"
  description = "Allow traffic for NAT instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [for s in aws_subnet.private : s.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "xelta-${var.environment}-nat-instance-sg"
  }
}

resource "aws_eip" "nat_instance" {
  count = var.enable_nat_gateway && var.enable_ec2_nat_instance ? 1 : 0

  # --- FIX: Changed deprecated 'vpc = true' to 'domain = "vpc"' ---
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
}

resource "aws_instance" "nat" {
  count                  = var.enable_nat_gateway && var.enable_ec2_nat_instance ? 1 : 0
  ami                    = data.aws_ami.amazon_linux_2_arm[0].id
  instance_type          = "t4g.micro"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.nat_instance[0].id]
  source_dest_check      = false

  tags = {
    Name = "xelta-${var.environment}-nat-instance"
  }
}

resource "aws_eip_association" "nat_instance" {
  count         = var.enable_nat_gateway && var.enable_ec2_nat_instance ? 1 : 0
  instance_id   = aws_instance.nat[0].id
  allocation_id = aws_eip.nat_instance[0].id
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

# Private Route Tables (one per AZ)
resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "xelta-${var.environment}-private-rt-${var.availability_zones[count.index]}"
    Environment = var.environment
  }
}

# ---
# --- CRITICAL FIX IS HERE ---
# ---

# Route for the AWS Managed NAT Gateway
resource "aws_route" "private_managed_nat" {
  # Create one route per AZ if the EC2 NAT is DISABLED
  count = !var.enable_ec2_nat_instance ? length(var.availability_zones) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
}

# Route for the cost-saving EC2 NAT Instance
resource "aws_route" "private_ec2_nat" {
  # Create one route per AZ if the EC2 NAT is ENABLED
  count = var.enable_ec2_nat_instance ? length(var.availability_zones) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  
  # --- FIX: Route to the Network Interface ID, not the Instance ID ---
  # This resolves all the "Invalid combination" errors.
  network_interface_id = aws_instance.nat[0].primary_network_interface_id
}

# ---
# --- END OF CRITICAL FIX ---
# ---


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
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_log.arn
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