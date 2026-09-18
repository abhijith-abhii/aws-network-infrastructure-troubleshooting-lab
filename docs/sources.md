# Official references reviewed

Reviewed on **2026-09-18**. These links support design decisions and syntax; they are not evidence of successful AWS execution. AWS pages and provider releases can change. Use the committed lock and record the deployed AMI/agent versions.

| Topic | Primary source | Used for |
|---|---|---|
| SSM private endpoints | [AWS Systems Manager VPC endpoints](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html) | SSM private DNS, inbound 443, optional extra service endpoints |
| Modern SSM messaging | [AWS messaging API reference](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-setting-up-messageAPIs.html) | Agent 3.3.40.0+ ssmmessages precedence; regional differences |
| Agent regional downloads | [AWS SSM technical details](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-agent-technical-details.html) | Agent/module S3 bucket permissions |
| Preinstalled agent | [AWS AMI/agent reference](https://docs.aws.amazon.com/systems-manager/latest/userguide/ami-preinstalled-agent.html) | Standard image agent verification |
| AL2023 package names | [AWS package comparison](https://docs.aws.amazon.com/linux/al2023/ug/amzn2-al2023-ami.html) | awscli-2, bind-utils and curl package family |
| Private package installation | [Official AWS re:Post AL2023 procedure](https://repost.aws/knowledge-center/ec2-al1-al2-update-yum-without-internet) | S3-hosted AL2023 repo allow-list and return traffic |
| Image/repository lifecycle | [AWS AL2023 updates](https://docs.aws.amazon.com/linux/al2023/ug/managing-repos-os-updates.html) | Image-associated repository versions and DNF |
| S3 gateway path | [AWS gateway endpoints for S3](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html) | Prefix-list routing, SG rules, gateway limitations, no endpoint charge |
| Private DNS | [AWS private hosted-zone considerations](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zone-private-considerations.html) | Associations, resolver behavior, private record scope |
| Flow direction and filtering | [AWS Flow Log examples](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-records-examples.html) | Stateful SG vs stateless ACL evidence |
| Flow Log limits | [AWS limitations](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-limitations.html) | Excluded traffic, delivery/evidence caveats |
| Endpoint Terraform schema | [HashiCorp provider source documentation](https://github.com/hashicorp/terraform-provider-aws/blob/main/website/docs/r/vpc_endpoint.html.markdown) | Interface/gateway fields, route association and private DNS |
| ACL Terraform schema | [HashiCorp provider source documentation](https://github.com/hashicorp/terraform-provider-aws/blob/main/website/docs/r/network_acl_rule.html.markdown) | Direction, ports, rule numbers, CIDR syntax |
| Flow Log Terraform schema | [HashiCorp registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | VPC/group/role/aggregation configuration |
| Lock file | [HashiCorp dependency lock documentation](https://developer.hashicorp.com/terraform/language/files/dependency-lock) | Generated checksums, commit and upgrade workflow |
| Tests | [HashiCorp provider mocking](https://developer.hashicorp.com/terraform/language/tests/mocking) | Offline schema-backed tests with mocked plan/apply phases |
| S3 backend | [HashiCorp backend documentation](https://developer.hashicorp.com/terraform/language/backend/s3) | Optional native S3 locking, encryption and permissions |

The Terraform Registry's JavaScript-only pages were supplemented by the official provider repository documentation and actual validation against the installed provider schema. Pricing references and dated assumptions are collected in [costs.md](costs.md).
