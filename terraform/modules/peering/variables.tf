variable "name" {
  description = "Resource prefix."
  type        = string
}

variable "client_vpc" {
  description = "Requester VPC ID."
  type        = string
}

variable "server_vpc" {
  description = "Accepter VPC ID."
  type        = string
}

variable "client_rt" {
  description = "Client private route table ID."
  type        = string
}

variable "server_rt" {
  description = "Server private route table ID."
  type        = string
}

variable "client_cidr" {
  description = "Only the client private workload CIDR."
  type        = string
}

variable "server_cidr" {
  description = "Only the server private workload CIDR."
  type        = string
}

variable "remove_forward" {
  description = "Remove the client route while keeping the reverse route."
  type        = bool
}
