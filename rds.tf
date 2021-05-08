output "rds_hostname" {
  description = "hostname of db_postgres_instance_0"
  value       = aws_db_instance.db_postgres_instance_0.address
}

resource "aws_subnet" "db_subnet_0" {
  vpc_id                  = aws_vpc.vpc_dev_main.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = "${var.region}${var.availability-zone}"
  map_public_ip_on_launch = "true"
  tags = {
    environment = var.env
  }
}

resource "aws_route_table_association" "rt-association_db_subnet_0" {
  subnet_id      = aws_subnet.db_subnet_0.id
  route_table_id = aws_route_table.rt_public_dev_main.id
}

resource "aws_subnet" "db_subnet_1" {
  vpc_id                  = aws_vpc.vpc_dev_main.id
  cidr_block              = "10.0.6.0/24"
  availability_zone       = "${var.region}${var.availability-zone_second}"
  map_public_ip_on_launch = "true"
  tags = {
    environment = var.env
  }
}

resource "aws_route_table_association" "rt-association_db_subnet_1" {
  subnet_id      = aws_subnet.db_subnet_1.id
  route_table_id = aws_route_table.rt_public_dev_main.id
}


resource "aws_db_subnet_group" "db_subnetgroup_0" {
  name       = "db_subnetgroup_0"
  subnet_ids = [aws_subnet.db_subnet_0.id, aws_subnet.db_subnet_1.id]
  tags = {
    environment = var.env
  }
}

# resource "aws_db_parameter_group" "db_parametergroup_0" {
#   name   = "db_parametergroup_0"
#   family = "postgres12"
# 
#   parameter {
#     name  = "log_connections"
#     value = "1"
#   }
# }

resource "aws_security_group" "db_sg_0" {
  name = "mydb1"

  description = "RDS postgres servers"
  vpc_id      = aws_vpc.vpc_dev_main.id

  # Allow access from anywhere, but only to postgres
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound traffic to everywhere on all ports
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "db_postgres_instance_0" {
  allocated_storage       = 20 # gigabytes
  backup_retention_period = 0  # in days
  db_subnet_group_name    = aws_db_subnet_group.db_subnetgroup_0.name
  engine                  = "postgres"
  engine_version          = "12.5"
  # name of rds-instance
  identifier     = trimspace(file("${path.module}/secrets/db_postgres_instance_0_identifier.txt"))
  instance_class = "db.t2.micro"
  multi_az       = false
  # name of database to create when the DB-instance is created
  name = trimspace(file("${path.module}/secrets/db_postgres_instance_0_databasename.txt"))
  # additional parameters for postgres, if not used, aws's default parameter-group is used (here)
  # parameter_group_name     = "mydbparamgroup1"
  password            = trimspace(file("${path.module}/secrets/db_postgres_instance_0_password.txt"))
  port                = 5432
  publicly_accessible = true
  # db.t2.micro does not support encryption at rest (free-tier)
  storage_encrypted      = false
  storage_type           = "gp2"
  username               = trimspace(file("${path.module}/secrets/db_postgres_instance_0_database_username.txt"))
  vpc_security_group_ids = [aws_security_group.db_sg_0.id]
}
