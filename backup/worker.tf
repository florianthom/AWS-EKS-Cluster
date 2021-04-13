

resource "aws_route_table" "rt_private_dev_main" {
  vpc_id = aws_vpc.vpc_dev_main.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name          = "private subnet rt"
    "environment" = "development"
  }
}


resource "aws_subnet" "subnet_private_dev_main" {
  vpc_id            = aws_vpc.vpc_dev_main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}${var.availability-zone_second}"
  map_public_ip_on_launch = "false"
  tags = {
    "environment" = "development"
  }
}

resource "aws_route_table_association" "rt-association_private_subnet_dev_main" {
  subnet_id      = aws_subnet.subnet_private_dev_main.id
  route_table_id = aws_route_table.rt_private_dev_main.id
}


resource "aws_security_group" "sg-private-subnet_dev_main" {
  name        = "not_allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.vpc_dev_main.id
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name          = "sg-private-subnet"
    "environment" = "development"
  }
}

resource "aws_network_interface" "nic-priv-subnet_dev_main" {
  subnet_id       = aws_subnet.subnet_private_dev_main.id
  private_ips     = ["10.0.2.10"]
  security_groups = [aws_security_group.sg-private-subnet_dev_main.id]
  tags = {
    "environment" = "development"
  }
}

resource "aws_instance" "ubuntu-worker-1" {
  ami               = "ami-0502e817a62226e03"
  instance_type     = "t3.micro"
  availability_zone = "${var.region}${var.availability-zone_second}"
  key_name          = aws_key_pair.ssh.key_name
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.nic-priv-subnet_dev_main.id
  }
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
}

resource "aws_vpc_endpoint_route_table_association" "vpc-endpoint-rt-private-association-s3_dev_main" {
  route_table_id  = aws_route_table.rt_private_dev_main.id
  vpc_endpoint_id = aws_vpc_endpoint.endpoint-s3_dev_main.id
}