# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-vpc"
  })
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-igw"
  })
}

# Create public subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-public-subnet-${count.index + 1}"
    Type = "Public"
  })
}

# Create private subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-private-subnet-${count.index + 1}"
    Type = "Private"
  })
}

# Create Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# Create NAT Gateways
resource "aws_nat_gateway" "main" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# Create public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-public-rt"
  })
}

# Create private route tables
resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-private-rt-${count.index + 1}"
  })
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate private subnets with private route tables
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Security group for Chia nodes
resource "aws_security_group" "chia_nodes" {
  name_prefix = "${var.project_name}-${var.environment}-chia-"
  description = "Security group for Chia blockchain nodes"
  vpc_id      = aws_vpc.main.id

  # Chia fullnode port
  ingress {
    from_port   = var.chia_port
    to_port     = var.chia_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Chia fullnode port"
  }

  # Chia RPC port (internal only)
  ingress {
    from_port   = var.chia_rpc_port
    to_port     = var.chia_rpc_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Chia RPC port"
  }

  # Chia farmer port
  ingress {
    from_port   = var.chia_farmer_port
    to_port     = var.chia_farmer_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Chia farmer port"
  }

  # SSH access (internal only)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "SSH access from within VPC"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chia-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security group for EFS
resource "aws_security_group" "efs" {
  name_prefix = "${var.project_name}-${var.environment}-efs-"
  description = "Security group for EFS mount targets"
  vpc_id      = aws_vpc.main.id

  # NFS port from Chia nodes
  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.chia_nodes.id]
    description     = "NFS access from Chia nodes"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-efs-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security group for Load Balancer
resource "aws_security_group" "load_balancer" {
  name_prefix = "${var.project_name}-${var.environment}-lb-"
  description = "Security group for Load Balancer"
  vpc_id      = aws_vpc.main.id

  # Chia fullnode port
  ingress {
    from_port   = var.chia_port
    to_port     = var.chia_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Chia fullnode port"
  }

  # Chia RPC port
  ingress {
    from_port   = var.chia_rpc_port
    to_port     = var.chia_rpc_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Chia RPC port"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-lb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}