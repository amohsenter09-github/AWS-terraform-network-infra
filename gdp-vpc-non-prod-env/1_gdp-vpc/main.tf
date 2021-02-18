
## This the main VCPs, it will be created based on the select workspace. 
resource "aws_vpc" "root_vpc" {
  cidr_block           = lookup(var.vpc_cidr_rang, terraform.workspace)
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  tags = {

    Name = terraform.workspace
  }
}

# resource "aws_instance" "foo" {
#   ami           = "ami-0fc970315c2d38f01" # us-west-1
#   instance_type = "t2.micro"
#   count = length(var.availability_zone)
#    subnet_id = aws_subnet.public_subnet[count.index].id
#    tags = {
#    Name = "instance_${count.index}"
#    }
# }

## internet gateway attachment to the VPCs
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.root_vpc.id
  tags = {
    Name = "${terraform.workspace}-igw"
  }
}

/**This is the elastice IP for NAT Gateways per availability_zone **/
resource "aws_eip" "nat_eip" {
  count = length(var.availability_zone)
  vpc   = true
  tags = {
    Name = "${terraform.workspace}-eip"
  }
  depends_on = [aws_internet_gateway.internet_gateway]
}
resource "aws_nat_gateway" "nat_gateway" {
  count         = length(var.availability_zone)
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public_subnet[count.index].id
  depends_on    = [aws_internet_gateway.internet_gateway]
  tags = {
    Name              = "${terraform.workspace}-nat"
    Availability_zone = element(var.availability_zone, count.index)
  }
}

/**These are the subnets structure with route table association **/
resource "aws_subnet" "private_subnet" {
  count             = length(var.availability_zone)
  vpc_id            = aws_vpc.root_vpc.id
  availability_zone = var.availability_zone[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr_rang[terraform.workspace], 3, count.index)

  tags = {
    Name = "${terraform.workspace}-private-subnet-${var.availability_zone[count.index]}"
  }
}
resource "aws_route_table" "private_route" {

  vpc_id = aws_vpc.root_vpc.id
  count  = length(var.availability_zone)
  route {

    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway[count.index].id
  }
  tags = {
    Name = "${terraform.workspace}-private-rt"
  }
}
resource "aws_route_table_association" "private_assoc" {
  count          = length(var.availability_zone)
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id =  aws_route_table.private_route[count.index].id

}
# Pulice subnet 
resource "aws_subnet" "public_subnet" {
  count             = length(var.availability_zone)
  vpc_id            = aws_vpc.root_vpc.id
  availability_zone = var.availability_zone[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr_rang[terraform.workspace], 4, count.index + 6)

  tags = {
    Name = "${terraform.workspace}-public-subnet-${var.availability_zone[count.index]}"
  }
}
resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.root_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    Name = "${terraform.workspace}-public-rt"
  }
}
resource "aws_route_table_association" "public_assoc" {
  count          = length(var.availability_zone)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_route.id
}

## Database subnet
resource "aws_subnet" "db_subnet" {
  count             = length(var.availability_zone)
  vpc_id            = aws_vpc.root_vpc.id
  availability_zone = var.availability_zone[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr_rang[terraform.workspace], 4, count.index + 9)
  tags = {
    Name = "${terraform.workspace}-subnet-db-${var.availability_zone[count.index]}"
  }
}
resource "aws_route_table" "db_route" {
  vpc_id = aws_vpc.root_vpc.id
  tags = {
    Name = "${terraform.workspace}-db-rt"
  }
}
resource "aws_route_table_association" "db_assoc" {
  count          = length(var.availability_zone)
  subnet_id      = aws_subnet.db_subnet[count.index].id
  route_table_id = aws_route_table.db_route.id
}


# # RDS subnet group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "gd_db_subnetgrp_${terraform.workspace}"
  subnet_ids = aws_subnet.db_subnet[*].id
  tags = {
    Name = "${terraform.workspace}-db-subnet-grp"
  }
}

# # RDS security group
resource "aws_security_group" "gd_rds_sg" {
  name        = "gd_rds_sg_${terraform.workspace}"
  description = "RDS security group allowed access"
  vpc_id      = aws_vpc.root_vpc.id

  ingress {
    description = "Allow MySQL port from private subnets"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = aws_subnet.private_subnet[*].cidr_block
  }

  tags = {
    Name = "${terraform.workspace}-db-sg"
  }
}

# RDS random string generator for password
resource "random_string" "rds_master_password" {
  length           = 40
  special          = true
  override_special = "!#-_"
}

# RDS master password
resource "aws_secretsmanager_secret" "rds_master_password" {
  name                    = "gdp/${split("-", terraform.workspace)[1]}/dbpw"
  recovery_window_in_days = 0
}

# RDS cluster
resource "aws_rds_cluster" "gd_rds" {
  cluster_identifier              = "${terraform.workspace}-db"
  engine                          = "aurora-mysql"
  engine_version                  = "5.7.mysql_aurora.2.07.1"
  engine_mode                     = "provisioned"
  database_name                   = "gdpmaster"
  master_username                 = "masteruser"
  master_password                 = random_string.rds_master_password.result
  db_subnet_group_name            = aws_db_subnet_group.db_subnet_group.name
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
  storage_encrypted               = true
  vpc_security_group_ids          = [aws_security_group.gd_rds_sg.id]
  preferred_maintenance_window    = "Mon:00:00-Mon:01:00"
  preferred_backup_window         = "02:00-02:30"
  apply_immediately               = true
  skip_final_snapshot             = true
  tags = {
    Name = "${terraform.workspace}-db"
  }
}

# RDS instances
resource "aws_rds_cluster_instance" "gd_rds_instances" {
  count                      = 2
  identifier                 = "${terraform.workspace}-db-${count.index}"
  cluster_identifier         = aws_rds_cluster.gd_rds.id
  instance_class             = var.db_instance_type
  engine                     = aws_rds_cluster.gd_rds.engine
  engine_version             = aws_rds_cluster.gd_rds.engine_version
  db_subnet_group_name       = aws_rds_cluster.gd_rds.db_subnet_group_name
  auto_minor_version_upgrade = false
  apply_immediately          = true
}

# Storing generated password on AWS_secret_manager
resource "aws_secretsmanager_secret_version" "rds_master_password" {
  secret_id     = aws_secretsmanager_secret.rds_master_password.id
  secret_string = random_string.rds_master_password.result
}


# route 53 zone ops.gd.bose.com

# dhcp options