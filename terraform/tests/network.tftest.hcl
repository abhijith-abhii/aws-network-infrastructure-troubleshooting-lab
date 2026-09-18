mock_provider "aws" {}
variables {
  name         = "test-server"
  cidr         = "10.20.0.0/16"
  public_cidr  = "10.20.0.0/24"
  private_cidr = "10.20.10.0/24"
  az           = "us-east-1a"
  peer_ip      = "10.10.10.10"
  is_server    = true
  block_return = false
}
run "baseline" {
  command = plan
  module { source = "./modules/network" }
  assert {
    condition     = length(aws_network_acl_rule.fault_return) == 0
    error_message = "Baseline cannot contain fault deny."
  }
  assert {
    condition     = aws_network_acl_rule.replies_in.from_port == 1024 && aws_network_acl_rule.replies_in.to_port == 65535
    error_message = "Allow ephemeral inbound responses."
  }
  assert {
    condition     = aws_network_acl_rule.http_return[0].egress && aws_network_acl_rule.http_return[0].cidr_block == "10.10.10.10/32"
    error_message = "Allow narrowly scoped HTTP returns."
  }
  assert {
    condition     = !aws_subnet.private.map_public_ip_on_launch
    error_message = "Private subnet must not assign public addresses."
  }
}
run "return_fault" {
  command = plan
  module { source = "./modules/network" }
  variables { block_return = true }
  assert {
    condition     = aws_network_acl_rule.fault_return[0].rule_number < aws_network_acl_rule.http_return[0].rule_number && aws_network_acl_rule.fault_return[0].egress && aws_network_acl_rule.fault_return[0].rule_action == "deny"
    error_message = "Fault must win outbound ACL ordering."
  }
  assert {
    condition     = aws_network_acl_rule.fault_return[0].from_port == 1024 && aws_network_acl_rule.fault_return[0].cidr_block == "10.10.10.10/32"
    error_message = "Fault must affect peer return traffic only."
  }
}
