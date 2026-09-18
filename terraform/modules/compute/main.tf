resource "aws_iam_role" "this" {
  name               = "${var.name}-ec2"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy" "s3" {
  name = "read-lab-and-regional-packages"
  role = aws_iam_role.this.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Allow", Action = ["s3:GetObject"], Resource = [
      var.object_arn,
      "arn:aws:s3:::al2023-repos-${var.region}-*/*",
      "arn:aws:s3:::amazon-ssm-${var.region}/*",
      "arn:aws:s3:::aws-ssm-${var.region}/*"
    ]
  }] })
}
resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-profile"
  role = aws_iam_role.this.name
}
resource "aws_security_group" "this" {
  name_prefix = "${var.name}-workload-"
  description = "Lab workload; no SSH; only explicit exercise and endpoint traffic"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-workload" }
}
resource "aws_vpc_security_group_egress_rule" "ssm" {
  security_group_id            = aws_security_group.this.id
  description                  = "Local SSM HTTPS endpoints"
  referenced_security_group_id = var.endpoint_sg_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
resource "aws_vpc_security_group_egress_rule" "s3" {
  for_each          = { http = 80, https = 443 }
  security_group_id = aws_security_group.this.id
  description       = "Regional S3 packages and test object; endpoint policy restricts objects"
  prefix_list_id    = var.s3_prefix_list
  ip_protocol       = "tcp"
  from_port         = each.value
  to_port           = each.value
}
resource "aws_vpc_security_group_egress_rule" "http" {
  count             = var.is_server ? 0 : 1
  security_group_id = aws_security_group.this.id
  description       = "Client HTTP exercise to exact server address"
  cidr_ipv4         = "${var.peer_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}
resource "aws_vpc_security_group_ingress_rule" "http" {
  count             = var.is_server && !var.block_http ? 1 : 0
  security_group_id = aws_security_group.this.id
  description       = "HTTP only from the exact client address"
  cidr_ipv4         = "${var.peer_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}
resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  private_ip                  = var.private_ip
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  ebs_optimized               = true
  monitoring                  = false
  user_data_replace_on_change = true
  user_data                   = templatefile("${path.module}/user-data.sh.tftpl", { is_server = var.is_server })
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }
  credit_specification { cpu_credits = "standard" }
  tags        = { Name = var.name }
  volume_tags = merge(var.tags, { Name = "${var.name}-root" })
  depends_on  = [aws_iam_role_policy_attachment.ssm, aws_iam_role_policy.s3, aws_vpc_security_group_egress_rule.ssm, aws_vpc_security_group_egress_rule.s3]
}
