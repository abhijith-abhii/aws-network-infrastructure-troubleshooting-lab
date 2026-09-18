data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}
data "aws_ssm_parameter" "al2023" {
  count = var.ami_id == null ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  az     = coalesce(var.availability_zone, sort(data.aws_availability_zones.available.names)[0])
  ami_id = var.ami_id == null ? data.aws_ssm_parameter.al2023[0].value : var.ami_id
  tags   = { Project = "AWS Network Infrastructure and Troubleshooting Lab", LabId = var.lab_id, Owner = var.owner, Environment = "personal-lab", ManagedBy = "Terraform" }
  networks = {
    client = { cidr = "10.10.0.0/16", public = "10.10.0.0/24", private = "10.10.10.0/24", ip = "10.10.10.10", peer_ip = "10.20.10.10" }
    server = { cidr = "10.20.0.0/16", public = "10.20.0.0/24", private = "10.20.10.0/24", ip = "10.20.10.10", peer_ip = "10.10.10.10" }
  }
  bucket_name = "${var.lab_id}-${var.expected_account_id}-${var.region}"
  object_arn  = "arn:aws:s3:::${local.bucket_name}/test/hello.txt"
}

module "network" {
  source       = "./modules/network"
  for_each     = local.networks
  name         = "${var.lab_id}-${each.key}"
  cidr         = each.value.cidr
  public_cidr  = each.value.public
  private_cidr = each.value.private
  az           = local.az
  peer_ip      = each.value.peer_ip
  is_server    = each.key == "server"
  block_return = each.key == "server" && var.scenario == "nacl"
}

module "peering" {
  source         = "./modules/peering"
  name           = var.lab_id
  client_vpc     = module.network["client"].vpc_id
  server_vpc     = module.network["server"].vpc_id
  client_rt      = module.network["client"].private_route_table_id
  server_rt      = module.network["server"].private_route_table_id
  client_cidr    = local.networks.client.private
  server_cidr    = local.networks.server.private
  remove_forward = var.scenario == "routing"
}

module "endpoints" {
  source           = "./modules/endpoints"
  for_each         = local.networks
  name             = "${var.lab_id}-${each.key}"
  region           = var.region
  vpc_id           = module.network[each.key].vpc_id
  subnet_id        = module.network[each.key].private_subnet_id
  route_table_id   = module.network[each.key].private_route_table_id
  workload_ip      = each.value.ip
  object_arn       = local.object_arn
  deny_test_object = each.key == "client" && var.scenario == "s3-policy"
}

module "compute" {
  source         = "./modules/compute"
  for_each       = local.networks
  name           = "${var.lab_id}-${each.key}"
  region         = var.region
  ami_id         = local.ami_id
  instance_type  = var.instance_type
  vpc_id         = module.network[each.key].vpc_id
  subnet_id      = module.network[each.key].private_subnet_id
  private_ip     = each.value.ip
  peer_ip        = each.value.peer_ip
  endpoint_sg_id = module.endpoints[each.key].security_group_id
  s3_prefix_list = module.endpoints[each.key].s3_prefix_list_id
  object_arn     = local.object_arn
  is_server      = each.key == "server"
  block_http     = each.key == "server" && var.scenario == "security-group"
  tags           = local.tags
  depends_on     = [module.endpoints, module.peering]
}

module "storage" {
  source       = "./modules/storage"
  bucket_name  = local.bucket_name
  endpoint_ids = [for e in module.endpoints : e.s3_endpoint_id]
  role_arns    = [for c in module.compute : c.role_arn]
}

module "logging" {
  source         = "./modules/logging"
  name           = var.lab_id
  region         = var.region
  account_id     = var.expected_account_id
  retention_days = var.log_retention_days
  vpc_ids        = { for k, n in module.network : k => n.vpc_id }
}

resource "aws_route53_zone" "lab" {
  name = "${var.lab_id}.internal"
  dynamic "vpc" {
    for_each = module.network
    content {
      vpc_id = vpc.value.vpc_id
    }
  }
  comment = "Personal lab private DNS only; no domain registration."
}

# Remove one A record; leave AWS endpoint resolution and SSM untouched.
resource "aws_route53_record" "app" {
  count   = var.scenario == "dns" ? 0 : 1
  zone_id = aws_route53_zone.lab.zone_id
  name    = "app.${aws_route53_zone.lab.name}"
  type    = "A"
  ttl     = 5
  records = [local.networks.server.ip]
}
