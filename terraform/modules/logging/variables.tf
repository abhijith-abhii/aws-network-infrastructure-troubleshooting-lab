variable "name" {
  description = "Lab resource prefix."
  type        = string
}

variable "region" {
  description = "Region used in source ARN trust constraint."
  type        = string
}

variable "account_id" {
  description = "Account used in source account trust constraint."
  type        = string
}

variable "retention_days" {
  description = "CloudWatch retention in days."
  type        = number
}

variable "vpc_ids" {
  description = "VPC identifiers to log."
  type        = map(string)
}
