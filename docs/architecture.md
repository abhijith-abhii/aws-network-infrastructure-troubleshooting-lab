# Architecture and address plan

The topology deliberately uses one common Availability Zone to reduce moving parts and avoid inter-AZ peering transfer in the default exercise. Terraform picks the alphabetically first available standard AZ, or accepts `availability_zone`. AZ labels differ between accounts; both VPCs here are in the same account.

## Addresses

| Component | Client VPC | Server VPC |
|---|---|---|
| VPC | `10.10.0.0/16` | `10.20.0.0/16` |
| Public subnet (empty) | `10.10.0.0/24` | `10.20.0.0/24` |
| Private workload subnet | `10.10.10.0/24` | `10.20.10.0/24` |
| EC2 fixed private IPv4 | `10.10.10.10` | `10.20.10.10` |
| SSM endpoint ENIs | Dynamic in private /24 | Dynamic in private /24 |
| VPC resolver | `10.10.0.2` | `10.20.0.2` |
| Peering route in private table | `10.20.10.0/24 → pcx` | `10.10.10.0/24 → pcx` |

AWS reserves the first four and last address of each subnet. `.10` is an intentional deterministic assignment, not a dynamic discovery assumption. CIDRs are fixed in root locals to keep all guides and packet paths consistent. Reusing these CIDRs in an unrelated VPC is possible, but do not peer overlapping networks or attach this lab to a real environment.

Every route table retains its automatic VPC-local route. Only public tables have `0.0.0.0/0 → IGW`. Private tables add the two explicit peer /24 routes and a regional S3 managed-prefix-list route through the local gateway endpoint. Gateway endpoints do not traverse peering. Both VPCs are associated with the private Route 53 zone directly; peering's EC2 public-DNS-resolution option is unnecessary for this custom private zone.

## Connectivity matrix (healthy baseline)

“Allowed” describes intended new connections; replies follow stateful SG rules and explicit ACL allowances. Verify deployment rather than treating this matrix as measured evidence.

| Source | Destination | Port/protocol | Baseline | Enforcement/evidence |
|---|---|---|---|---|
| Client `.10.10` | Server `10.20.10.10` | TCP 80 | Allow | Peer routes, client egress, server ingress, ACLs; HTTP body test |
| Server | Client | HTTP response to TCP 40000–40100 in scripted tests | Allow | SG connection tracking; server ACL return rule + client ephemeral ingress |
| Server | Client | New TCP 80 | Deny | Neither server egress nor client ingress allows it |
| Either instance | Other instance | TCP 22, 3389; ICMP | Deny | No matching SG rules; no SSH key installed |
| Either instance | Local SSM / ssmmessages ENI | TCP 443 | Allow | Workload egress references endpoint SG; endpoint ingress exact workload /32 |
| Other VPC workload | Peer's SSM endpoints | TCP 443 | Deny | Endpoint SG source /32 is local; no cross-VPC SSM egress grant |
| Either instance | Regional S3 test object | TCP 443, signed GetObject | Allow | Local gateway route, prefix-list SG, IAM/object/endpoint policy |
| Either instance | AL2023 and selected SSM regional buckets | TCP 80/443, GetObject | Allow | Prefix-list SG; endpoint allow-list. Bootstrap DNF uses AL2023 repository |
| Either instance | Arbitrary S3 bucket/object | TCP 80/443 | Deny at authorization | Endpoint policy doesn't allow it; instance role lacks permission |
| Either instance | Test object over plaintext HTTP | TCP 80 | Deny at authorization | Bucket policy requires TLS |
| Either instance | AmazonProvidedDNS | UDP/TCP 53 | Allow | AWS resolver; SG/NACL cannot block this built-in resolver |
| Internet or workstation | Either instance | Any direct IP traffic | Deny/unroutable | No public IPv4, private default route, or inbound administrative rules |
| Either instance | General public Internet | Any | Deny/unroutable | No private default route/NAT; SG restricts egress |
| Public reserved subnet | Any workload | Any | Deny | Empty subnet with deny-all ACL |
| Authorized operator | Managed node | Session Manager | Allow | Operator IAM + service + instance-initiated TLS channel |

Instance metadata (IMDSv2), DHCP, Amazon Time Sync and resolver platform traffic have AWS-specific handling; a catch-all SG/ACL claim would be misleading. IMDS requires tokens and uses hop limit 1. The lab does not use IPv6.

## ACL rules

Private ACLs allow outbound TCP 80/443 to `0.0.0.0/0`, inbound TCP 1024–65535 from `0.0.0.0/0`, and local-subnet HTTPS/return traffic. NACLs cannot reference S3 prefix lists, so the SG and endpoint policy impose the finer constraints. Same-subnet endpoint traffic does not cross the subnet ACL boundary.

Only the server ACL adds inbound TCP/80 from `10.10.10.10/32` (rule 100) and outbound TCP/1024–65535 to the same client (rule 140). The fault inserts rule 90, an outbound deny over that range to that one client. Lower rule numbers win; the final implicit rule denies other traffic. Linux normally chooses a narrower ephemeral range, but 1024–65535 safely covers OS variation. Scripted HTTP probes bind within 40000–40100.

## Module responsibilities

- `network`: VPC, subnets, IGW, public/private tables, ACLs, and locked-down default SG.
- `peering`: peering connection and the two private workload routes.
- `endpoints`: local SSM endpoints and S3 route/policy.
- `compute`: instance role/profile, explicit SG rules, encrypted disk, bootstrap and HTTP service.
- `storage`: private encrypted bucket, one object, and TLS/endpoint path policies.
- `logging`: service delivery role and shared Flow Log group.

Root wiring owns DNS, global tags, inputs and the single scenario selector. The project has no cross-account connections, multi-AZ failover, traffic inspection appliance, or production service-level objective.
