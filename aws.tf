# ------------------------------------------------------
# VPC
# ------------------------------------------------------
resource "aws_vpc" "babu_gko_vpc" {
  cidr_block = "10.8.0.0/16"

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.owner}-gko-vpc"
  }

}

# ------------------------------------------------------
# SUBNETS
# ------------------------------------------------------

resource "aws_subnet" "babu_gko_public_subnets" {
  for_each                = var.subnet_mappings
  vpc_id                  = aws_vpc.babu_gko_vpc.id
  map_public_ip_on_launch = true
  cidr_block              = "10.8.${each.value.subnet}.0/24"

  availability_zone_id = "use1-${each.key}"
  tags = {
    Name = "${var.owner}-public-subnet-${each.value.az}"
  }
}

# ------------------------------------------------------
# IGW
# ------------------------------------------------------
resource "aws_internet_gateway" "babu_gko_ig" {
  vpc_id = aws_vpc.babu_gko_vpc.id

  tags = {
    Name = "${var.owner}-igw"
  }
}
# ------------------------------------------------------
# ROUTE TABLE
# ------------------------------------------------------
resource "aws_route_table" "babu_gko_route_table" {
  vpc_id = aws_vpc.babu_gko_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.babu_gko_ig.id
  }
  tags = {
    Name = "${var.owner}-route-table"
  }
}

# ------------------------------------------------------
# ROUTE TABLE SUBNET ASSOCIATION
# ------------------------------------------------------
resource "aws_route_table_association" "babu_gko_subnet_associations" {
  for_each       = var.subnet_mappings
  subnet_id      = aws_subnet.babu_gko_public_subnets["${each.key}"].id
  route_table_id = aws_route_table.babu_gko_route_table.id
}

# ------------------------------------------------------
# SECURITY GROUP
# ------------------------------------------------------
resource "aws_security_group" "babu_oracle_sg" {
  name        = "babu_oracle_security_group"
  description = "Oracle DB Security Group"
  vpc_id      = aws_vpc.babu_gko_vpc.id
  egress {
    description = "Allow all outbound."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Postgres"
    from_port   = 1521
    to_port     = 1521
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.owner}-oracle-sg"
  }
}

# ------------------------------------------------------
# DB SUBNET GROUP
# ------------------------------------------------------
resource "aws_db_subnet_group" "babu_gko_db_subnet_group" {
  name       = "babu-db-subnet-group"
  subnet_ids = [aws_subnet.babu_gko_public_subnets["az2"].id, aws_subnet.babu_gko_public_subnets["az4"].id]

  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_db_instance" "babu_gko_oracle_db" {

  identifier     = "babu-oracledb"
  engine         = "oracle-se2"
  engine_version = "19"
  instance_class = "db.m5.large"
  #   instance_type = "db.m5.large"
  allocated_storage      = 100
  max_allocated_storage  = 100
  storage_type           = "gp2"
  license_model          = "license-included"
  db_name                = "ORACLE"
  username               = var.oracle_admin_username
  password               = var.oracle_admin_password
  port                   = 1521
  vpc_security_group_ids = [aws_security_group.babu_oracle_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.babu_gko_db_subnet_group.id
  network_type           = "IPV4"
  publicly_accessible    = "true"
  skip_final_snapshot    = "true"
  multi_az               = "false"
  performance_insights_enabled  = "false"


  final_snapshot_identifier = "babu-snapshot"


  tags = {
    Name = "babu-oracledb"
  }

}
