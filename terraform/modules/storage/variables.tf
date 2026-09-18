variable "bucket_name" {
  description = "Globally unique dedicated lab bucket."
  type        = string
}

variable "endpoint_ids" {
  description = "Two allowed S3 gateway endpoint IDs."
  type        = list(string)
}

variable "role_arns" {
  description = "Instance roles subject to the endpoint path constraint."
  type        = list(string)
}
