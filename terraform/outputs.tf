output "lab" {
  description = "Machine-readable inventory consumed by scripts; treat account and IDs as private evidence."
  value = {
    lab_id       = var.lab_id
    account_id   = data.aws_caller_identity.current.account_id
    region       = var.region
    az           = local.az
    scenario     = var.scenario
    hostname     = "app.${var.lab_id}.internal"
    bucket       = module.storage.bucket_name
    object_key   = "test/hello.txt"
    log_group    = module.logging.log_group_name
    peering_id   = module.peering.id
    zone_id      = aws_route53_zone.lab.zone_id
    flow_log_ids = module.logging.flow_log_ids
    instances = { for k, c in module.compute : k => {
      id   = c.instance_id, ip = c.private_ip, eni = c.eni_id, sg = c.security_group_id,
      role = c.role_name, profile = c.profile_name, ami = c.ami_id
    } }
    networks = { for k, n in module.network : k => {
      vpc_id                 = n.vpc_id, private_route_table_id = n.private_route_table_id,
      private_subnet_id      = n.private_subnet_id, private_acl_id = n.private_acl_id,
      s3_endpoint_id         = module.endpoints[k].s3_endpoint_id,
      interface_endpoint_ids = module.endpoints[k].interface_endpoint_ids
    } }
    session_commands = { for k, c in module.compute : k => "aws ssm start-session --region ${var.region} --target ${c.instance_id}" }
  }
}
