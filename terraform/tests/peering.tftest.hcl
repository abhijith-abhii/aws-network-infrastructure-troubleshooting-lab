mock_provider "aws" {}
variables {
  name           = "test"
  client_vpc     = "vpc-11111111"
  server_vpc     = "vpc-22222222"
  client_rt      = "rtb-11111111"
  server_rt      = "rtb-22222222"
  client_cidr    = "10.10.10.0/24"
  server_cidr    = "10.20.10.0/24"
  remove_forward = false
}
run "baseline" {
  command = plan
  module { source = "./modules/peering" }
  assert {
    condition     = length(aws_route.client_to_server) == 1 && aws_route.server_to_client.destination_cidr_block == "10.10.10.0/24"
    error_message = "Baseline needs both routes."
  }
}
run "routing_fault" {
  command = plan
  module { source = "./modules/peering" }
  variables { remove_forward = true }
  assert {
    condition     = length(aws_route.client_to_server) == 0 && aws_route.server_to_client.destination_cidr_block == "10.10.10.0/24"
    error_message = "Only forward route removed."
  }
}
