# create subnets inside the vpc
resource "aws_subnet" "subnet_public" {
  vpc_id                  = aws_vpc.vpc_dev_main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "${var.region}${var.availability-zone}"
  map_public_ip_on_launch = "true"
  tags = {
    environment = var.env
  }
}


# connect subnet inside of the vpc with routing table of vpc (=create association between both)
resource "aws_route_table_association" "rt-association_public_subnet_dev_main" {
  subnet_id      = aws_subnet.subnet_public.id
  route_table_id = aws_route_table.rt_public_dev_main.id
}


# the firewall of the ec2
# -1 is a possible value for from_port, to_port, protocol,
#   = all devices which have this security group attached can communicate with each other
# 0 is a possible value for from_port, to_port, protocol
#   = open for all
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-group-rules-reference.html
# so currently other nodes with this sg can be ssh-ed from all + ping (only each other)
#   since no other worker exists (with this sg), the icmp-part is useless
resource "aws_security_group" "sg_public_subnet_dev_main" {
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
    Name        = "sg-public-subnet"
    environment = var.env
  }
}

# network-interface
resource "aws_network_interface" "nic-jumphost" {
  subnet_id       = aws_subnet.subnet_public.id
  private_ips     = ["10.0.0.10"]
  security_groups = [aws_security_group.sg_public_subnet_dev_main.id]
  tags = {
    environment = var.env
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
  # iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  tags = {
    environment = var.env
  }
}
