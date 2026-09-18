variable "name" {
  description = "Resource name prefix."
  type        = string
}

variable "cidr" {
  description = "VPC IPv4 CIDR."
  type        = string
}

variable "public_cidr" {
  description = "Reserved public subnet IPv4 CIDR."
  type        = string
}

variable "private_cidr" {
  description = "Workload subnet IPv4 CIDR."
  type        = string
}

variable "az" {
  description = "Shared Availability Zone."
  type        = string
}

variable "peer_ip" {
  description = "Peer workload private IPv4 address."
  type        = string
}

variable "is_server" {
  description = "Whether this VPC hosts the HTTP server."
  type        = bool
}

variable "block_return" {
  description = "Insert one return-path NACL deny rule for the exercise."
  type        = bool
}
