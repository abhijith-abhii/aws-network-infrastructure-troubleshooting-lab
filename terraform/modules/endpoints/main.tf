resource "aws_security_group" "endpoint" {
  name_prefix = "${var.name}-endpoint-"
  description = "Private SSM endpoints; responses are stateful"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-endpoint" }
}
resource "aws_vpc_security_group_ingress_rule" "ssm" {
  security_group_id = aws_security_group.endpoint.id
  description       = "HTTPS from this VPC workload only"
  cidr_ipv4         = "${var.workload_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
resource "aws_vpc_endpoint" "ssm" {
  for_each            = toset(["ssm", "ssmmessages"])
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.subnet_id]
  security_group_ids  = [aws_security_group.endpoint.id]
  private_dns_enabled = true
  tags                = { Name = "${var.name}-${each.key}" }
}
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [var.route_table_id]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid       = "RegionalAmazonLinuxAndAgentDownloads"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource = [
          "arn:aws:s3:::al2023-repos-${var.region}-*/*",
          "arn:aws:s3:::amazon-ssm-${var.region}/*",
          "arn:aws:s3:::aws-ssm-${var.region}/*"
        ]
      },
      { Sid = "TestObject", Effect = "Allow", Principal = "*", Action = ["s3:GetObject"], Resource = var.object_arn }
      ], var.deny_test_object ? [
      { Sid = "LabFaultDenyTestObject", Effect = "Deny", Principal = "*", Action = ["s3:GetObject"], Resource = var.object_arn }
    ] : [])
  })
  tags = { Name = "${var.name}-s3" }
}
output "security_group_id" {
  value = aws_security_group.endpoint.id
}
output "s3_prefix_list_id" {
  value = aws_vpc_endpoint.s3.prefix_list_id
}
output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}
output "interface_endpoint_ids" {
  value = [for e in aws_vpc_endpoint.ssm : e.id]
}
