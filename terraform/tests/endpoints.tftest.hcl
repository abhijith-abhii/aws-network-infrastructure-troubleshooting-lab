mock_provider "aws" {}
variables {
  name             = "test"
  region           = "us-east-1"
  vpc_id           = "vpc-11111111"
  subnet_id        = "subnet-11111111"
  route_table_id   = "rtb-11111111"
  workload_ip      = "10.10.10.10"
  object_arn       = "arn:aws:s3:::test-lab/test/hello.txt"
  deny_test_object = false
}
run "baseline" {
  command = plan
  module { source = "./modules/endpoints" }
  assert {
    condition     = length(aws_vpc_endpoint.ssm) == 2 && aws_vpc_endpoint.ssm["ssm"].private_dns_enabled && aws_vpc_endpoint.ssm["ssmmessages"].private_dns_enabled
    error_message = "Both management services need private DNS."
  }
  assert {
    condition     = length(jsondecode(aws_vpc_endpoint.s3.policy).Statement) == 2
    error_message = "Baseline allows only package and test reads."
  }
}
run "s3_fault" {
  command = plan
  module { source = "./modules/endpoints" }
  variables { deny_test_object = true }
  assert {
    condition     = jsondecode(aws_vpc_endpoint.s3.policy).Statement[2].Effect == "Deny" && jsondecode(aws_vpc_endpoint.s3.policy).Statement[2].Resource == "arn:aws:s3:::test-lab/test/hello.txt"
    error_message = "Deny must target only test object."
  }
  assert {
    condition     = length(aws_vpc_endpoint.ssm) == 2
    error_message = "Management endpoints retained."
  }
}
