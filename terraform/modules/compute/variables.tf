variable "name" {
  description = "Name prefix."
  type        = string
}

variable "region" {
  description = "AWS Region."
  type        = string
}

variable "ami_id" {
  description = "Standard AL2023 x86_64 AMI."
  type        = string
}

variable "instance_type" {
  description = "Small x86_64 T3 instance."
  type        = string
}

variable "vpc_id" {
  description = "Workload VPC ID."
  type        = string
}

variable "subnet_id" {
  description = "Private subnet ID."
  type        = string
}

variable "private_ip" {
  description = "Stable workload IPv4 address."
  type        = string
}

variable "peer_ip" {
  description = "Stable other workload IPv4 address."
  type        = string
}

variable "endpoint_sg_id" {
  description = "Local SSM endpoint security group."
  type        = string
}

variable "s3_prefix_list" {
  description = "Regional S3 managed prefix list."
  type        = string
}

variable "object_arn" {
  description = "Exact read-only lab test object."
  type        = string
}

variable "is_server" {
  description = "Start HTTP only on the server."
  type        = bool
}

variable "block_http" {
  description = "Remove destination HTTP ingress for exercise."
  type        = bool
}

variable "tags" {
  description = "Common lab ownership tags, explicitly applied to EBS volumes."
  type        = map(string)
  default     = {}
}
