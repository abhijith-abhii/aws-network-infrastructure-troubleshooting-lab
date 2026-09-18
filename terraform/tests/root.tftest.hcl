mock_provider "aws" {
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock-lab-role" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:123456789012:log-group:/personal-lab/mock/vpc-flow" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::mock-lab-bucket" }
  }
  mock_data "aws_availability_zones" {
    defaults = { names = ["us-east-1a"] }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
}
variables {
  expected_account_id = "123456789012"
  ami_id              = "ami-0123456789abcdef0"
}
run "baseline" {
  command = apply
  assert {
    condition     = length(aws_route53_record.app) == 1 && aws_route53_record.app[0].records == toset(["10.20.10.10"])
    error_message = "Baseline must publish the server private address."
  }
  assert {
    condition     = length(aws_route53_zone.lab.vpc) == 2
    error_message = "Both VPCs must share the private DNS zone."
  }
}
run "dns_fault" {
  command = apply
  variables { scenario = "dns" }
  assert {
    condition     = length(aws_route53_record.app) == 0 && length(aws_route53_zone.lab.vpc) == 2
    error_message = "DNS fault must remove only the app record and retain VPC associations."
  }
}
run "invalid_scenario" {
  command = plan
  variables { scenario = "all" }
  expect_failures = [var.scenario]
}
