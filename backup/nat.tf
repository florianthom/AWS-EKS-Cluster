# # eip for all traffic
# resource "aws_eip" "nat_gateway" {
#   vpc = true
#   depends_on                = [aws_internet_gateway.gw_dev_main]
# }

# # nat for all traffic
# # routing: (evt. priv subnet) -> nat (with eip) -> public subnet -> public subnet attached route-table -> gateway
# # in contrast jumphost: host with eip-attached nic -> public subnet -> public subnet attached route-table -> gateway
# resource "aws_nat_gateway" "nat_gateway" {
#   allocation_id = aws_eip.nat_gateway.id
#   # subnet in which to place nat
#   subnet_id = aws_subnet.subnet_public.id
#   tags = {
#     "Name" = "DummyNatGateway"
#   }
# }