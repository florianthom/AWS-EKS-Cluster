# create eip for the webserver
resource "aws_eip" "eip_jumphost" {
  vpc                       = true
  network_interface         = aws_network_interface.nic-jumphost.id
  associate_with_private_ip = var.jumphost-private-ip
  depends_on                = [aws_internet_gateway.gw_dev_main]
  tags = {
    "environment" = "development"
  }
}

# create subnets inside the vpc
resource "aws_subnet" "subnet_public" {
  vpc_id            = aws_vpc.vpc_dev_main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}${var.availability-zone}"
  map_public_ip_on_launch = "true"
  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
    iac_environment                             = "development"
  }
}


# connect subnet inside of the vpc with routing table of vpc (=create association between both)
resource "aws_route_table_association" "rt-association_public_subnet_dev_main" {
  subnet_id      = aws_subnet.subnet_public.id
  route_table_id = aws_route_table.rt_public_dev_main.id
}


# create a general secruity group
#   are the configuration files for the firewall of the ec2
resource "aws_security_group" "sg-public-subnet_dev_main" {
  name        = "allow_web_traffic_new"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.vpc_dev_main.id
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name          = "sg-public-subnet"
    "environment" = "development"
  }
}

# network-interface
resource "aws_network_interface" "nic-jumphost" {
  subnet_id = aws_subnet.subnet_public.id
  private_ips     = [var.jumphost-private-ip]
  security_groups = [aws_security_group.sg-public-subnet_dev_main.id]
  tags = {
    "environment" = "development"
  }
}

# instance
resource "aws_instance" "ubuntu-jumphost" {
  ami               = "ami-0502e817a62226e03"
  instance_type     = "t3.micro"
  availability_zone = "${var.region}${var.availability-zone}"
  key_name          = aws_key_pair.ssh.key_name
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.nic-jumphost.id
  }
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  tags = {
    "environment" = "development"
  }
}
