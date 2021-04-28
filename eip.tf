# create eip for the jumphost
resource "aws_eip" "eip_jumphost" {
  vpc               = true
  network_interface = aws_network_interface.nic-jumphost.id
  # see private ip of jumphost (=10.0.0.10)
  associate_with_private_ip = "10.0.0.10"
  depends_on                = [aws_internet_gateway.gw_dev_main]
  tags = {
    Name        = "jumphost eip"
    environment = var.env
  }
}
