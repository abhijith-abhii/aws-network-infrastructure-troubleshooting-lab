mock_provider "aws" {}
variables {
  name           = "test"
  region         = "us-east-1"
  ami_id         = "ami-0123456789abcdef0"
  instance_type  = "t3.micro"
  vpc_id         = "vpc-11111111"
  subnet_id      = "subnet-11111111"
  private_ip     = "10.20.10.10"
  peer_ip        = "10.10.10.10"
  endpoint_sg_id = "sg-11111111"
  s3_prefix_list = "pl-11111111"
  object_arn     = "arn:aws:s3:::test-lab/test/hello.txt"
  is_server      = true
  block_http     = false
}
run "baseline" {
  command = plan
  module { source = "./modules/compute" }
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.http) == 1 && aws_vpc_security_group_ingress_rule.http[0].cidr_ipv4 == "10.10.10.10/32"
    error_message = "Only exact client may reach HTTP."
  }
  assert {
    condition     = aws_instance.this.metadata_options[0].http_tokens == "required" && !aws_instance.this.associate_public_ip_address
    error_message = "IMDSv2 and no public IP required."
  }
  assert {
    condition     = aws_instance.this.root_block_device[0].encrypted && aws_instance.this.root_block_device[0].delete_on_termination
    error_message = "Root disk must be encrypted and deleted with instance."
  }
}
run "sg_fault" {
  command = plan
  module { source = "./modules/compute" }
  variables { block_http = true }
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.http) == 0 && aws_vpc_security_group_egress_rule.ssm.to_port == 443
    error_message = "HTTP removed; SSM outbound retained."
  }
}
run "client" {
  command = plan
  module { source = "./modules/compute" }
  variables { is_server = false }
  assert {
    condition     = length(aws_vpc_security_group_egress_rule.http) == 1 && length(aws_vpc_security_group_ingress_rule.http) == 0
    error_message = "Client initiates HTTP, never accepts it."
  }
}
