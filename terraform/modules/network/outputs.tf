output "vpc_id" {
  value = aws_vpc.this.id
}
output "private_subnet_id" {
  value = aws_subnet.private.id
}
output "private_route_table_id" {
  value = aws_route_table.private.id
}
output "private_acl_id" {
  value = aws_network_acl.private.id
}
