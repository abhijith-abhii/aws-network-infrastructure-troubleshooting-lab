variable "name" {
  description = "Resource prefix."
  type        = string
}

variable "region" {
  description = "AWS Region."
  type        = string
}

variable "vpc_id" {
  description = "Endpoint VPC."
  type        = string
}

variable "subnet_id" {
  description = "One private subnet in the common AZ."
  type        = string
}

variable "route_table_id" {
  description = "Private route table for S3 association."
  type        = string
}

variable "workload_ip" {
  description = "Only workload allowed to initiate SSM HTTPS."
  type        = string
}

variable "object_arn" {
  description = "Exact permitted lab test object."
  type        = string
}

variable "deny_test_object" {
  description = "Explicitly deny only the test object through this endpoint."
  type        = bool
}
