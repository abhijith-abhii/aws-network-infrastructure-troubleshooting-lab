resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.name }
}
resource "aws_default_security_group" "this" {
  vpc_id  = aws_vpc.this.id
  ingress = []
  egress  = []
  tags    = { Name = "${var.name}-unused-default-deny" }
}
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_cidr
  availability_zone       = var.az
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.name}-public-reserved", Tier = "public" }
}
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_cidr
  availability_zone       = var.az
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.name}-private", Tier = "private" }
}
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = var.name }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-public" }
}
resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-private-no-default-route" }
}
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
# Empty public subnet has deny-all ACL. No workload is placed here.
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = [aws_subnet.public.id]
  tags       = { Name = "${var.name}-public-deny" }
}
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = [aws_subnet.private.id]
  tags       = { Name = "${var.name}-private" }
}
# ACLs cannot reference the S3 prefix list. SG egress narrows these destinations.
resource "aws_network_acl_rule" "service_egress" {
  for_each       = { http = 80, https = 443 }
  network_acl_id = aws_network_acl.private.id
  rule_number    = each.value == 80 ? 110 : 120
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = each.value
  to_port        = each.value
}
resource "aws_network_acl_rule" "replies_in" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 120
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}
resource "aws_network_acl_rule" "local_https_in" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.private_cidr
  from_port      = 443
  to_port        = 443
}
resource "aws_network_acl_rule" "local_replies_out" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 130
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.private_cidr
  from_port      = 1024
  to_port        = 65535
}
resource "aws_network_acl_rule" "http_in" {
  count          = var.is_server ? 1 : 0
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${var.peer_ip}/32"
  from_port      = 80
  to_port        = 80
}
resource "aws_network_acl_rule" "http_return" {
  count          = var.is_server ? 1 : 0
  network_acl_id = aws_network_acl.private.id
  rule_number    = 140
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "${var.peer_ip}/32"
  from_port      = 1024
  to_port        = 65535
}
# Only this lower-numbered rule changes in the NACL exercise.
resource "aws_network_acl_rule" "fault_return" {
  count          = var.block_return ? 1 : 0
  network_acl_id = aws_network_acl.private.id
  rule_number    = 90
  egress         = true
  protocol       = "tcp"
  rule_action    = "deny"
  cidr_block     = "${var.peer_ip}/32"
  from_port      = 1024
  to_port        = 65535
}
