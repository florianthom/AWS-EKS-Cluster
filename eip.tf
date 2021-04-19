# create eip for the jumphost
resource "aws_eip" "eip_jumphost" {
  vpc                       = true
  network_interface         = aws_network_interface.nic-jumphost.id
  associate_with_private_ip = var.jumphost-private-ip
  depends_on                = [aws_internet_gateway.gw_dev_main]
  tags = {
    "environment" = "production"
  }
}

# create eip for kubernetes ingress-controller (which will assign this ip to the possibly created ingress-ressource)
# in short: create a static ip for the "webserver"
resource "aws_eip" "eip_kubernetes_ingress" {
  vpc        = true
  depends_on = [aws_internet_gateway.gw_dev_main]
  tags = {
    "environment" = "production"
  }
}
