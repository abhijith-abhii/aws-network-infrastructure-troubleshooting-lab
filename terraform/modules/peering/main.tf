resource "aws_vpc_peering_connection" "this" {
  vpc_id      = var.client_vpc
  peer_vpc_id = var.server_vpc
  auto_accept = true
  tags        = { Name = "${var.name}-peering" }
}
resource "aws_route" "client_to_server" {
  count                     = var.remove_forward ? 0 : 1
  route_table_id            = var.client_rt
  destination_cidr_block    = var.server_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}
resource "aws_route" "server_to_client" {
  route_table_id            = var.server_rt
  destination_cidr_block    = var.client_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}
output "id" {
  value = aws_vpc_peering_connection.this.id
}
