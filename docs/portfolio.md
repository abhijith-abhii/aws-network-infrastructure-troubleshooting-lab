# Interview discussion and honest portfolio language

## Questions and answers tied to this implementation

1. **Why are the workload subnets private?** Their associated AWS route tables have no default internet route, instances get no public address, and egress is limited to service endpoints and one peer HTTP target. A subnet's name alone doesn't make it private.
2. **What makes peering work?** Non-overlapping VPC CIDRs, active peering, forward and return workload /24 routes, and filters that admit request and response traffic. Peering is not transitive and does not share an S3 gateway endpoint with another VPC.
3. **Why does Session Manager survive the route fault?** Each VPC has local `ssm`/`ssmmessages` endpoints. Agent-initiated TLS uses local routes, not the removed peer route. A current standard AL2023 image and correct IAM are prerequisites.
4. **Why not a NAT gateway?** AL2023 packages are available from S3-hosted regional repositories and the gateway endpoint allows those buckets. SSM uses private interface endpoints. This narrow dependency set makes NAT unnecessary; external repos would change that decision.
5. **Why do ACLs need ephemeral return rules but SGs do not?** SGs track the established flow. ACLs independently filter each direction, so the server-to-client reply destination port must be permitted. Rule 90 deliberately wins over rule 140 in the NACL exercise.
6. **Why can `ip route` look normal during a routing incident?** It displays the guest kernel's routes. The AWS virtual router evaluates a separate subnet route table not visible in that command.
7. **How do you separate DNS from application reachability?** Compare curl by name, by IP, and with `--resolve`, then inspect `dig` status and Route 53 records. The missing A record produces NXDOMAIN; direct-IP HTTP remains healthy.
8. **Does a public S3 DNS address mean traffic used the internet?** No. The regional prefix-list route selects the gateway endpoint, and the bucket requires the instance role's reads to come through the lab endpoint IDs. The private table has no general internet route.
9. **Can Flow Logs explain an S3 403?** No. They can show captured IP traffic, not IAM decisions or HTTP contents. I compare role, bucket and endpoint policies, the controlled Terraform change and the unaffected server's read.
10. **How are experiments repeatable?** One validated scenario variable, guarded one-resource plans, baseline checks before injection, explicit restoration and healthy/unaffected tests afterward. No unexplained manual AWS modifications are required.
11. **How do you know teardown worked?** Empty state alone is insufficient. The controller preserves resource IDs, checks terminal/not-found service responses and absence of lab volumes/endpoints/roles/bucket/zone/logs, then I review delayed billing. An AWS authorization error is never treated as absence.
12. **What would change for production?** Multi-AZ workloads, resilient application serving, TLS, identity/boundary review, hardened image lifecycle, logging/audit requirements, stronger delivery pipelines and tested recovery objectives. This lab doesn't establish those properties.
13. **What is the largest fixed cost?** Four interface endpoints at the stated us-east-1 rate exceed the two tiny EC2 instances' combined monthly runtime cost. Deleting the lab matters; stopping instances leaves endpoints billed.
14. **What does static CI prove?** Formatting, provider schema consistency, mocked configuration behavior, script safety contracts and a selected security policy set. It doesn't prove regional capacity, IAM permissions, package bootstrap, live request paths or delivery latency.

## Resume templates

Use “personal project” and fill only measured/verified placeholders. If a live test has not run, use “implemented” rather than “validated” or “operated.”

- Built a **personal AWS networking lab** using Terraform modules for two VPCs, private EC2 workloads, VPC peering, Systems Manager access and S3 endpoints; [validated/deployment pending] in [Region/date].
- Implemented five controlled fault scenarios spanning routing, security groups, network ACLs, DNS and S3 endpoint authorization; documented [N completed] investigations with [measured median recovery time, only if actually measured].
- Added credential-free CI and automated baseline/recovery checks; recorded [actual test count] passing static checks and [actual live scenarios completed] AWS exercises with redacted evidence.
- Estimated lab cost from official AWS prices and verified [N] teardown cycles using resource-level removal checks; measured actual spend of [amount/time interval, only from billing records].

Do not say you improved company uptime, supported production incidents, delivered high availability, or achieved a latency/cost reduction you haven't measured.

## Known limitations and optional improvements

- Single AZ, one node per VPC, no application redundancy, TLS or production hardening.
- Modern AL2023 standard image only; packages and endpoint behavior must be verified on a real deployment. Image pin is local, so teammates must record/share the chosen non-secret AMI ID deliberately.
- Static tests use mocks and cannot detect every AWS API dependency, organizational policy, quota or availability constraint.
- DNS negative caching can make restoration slow. Flow Logs are delayed, best-effort and not packet captures.
- No S3 data-event CloudTrail, DNS query logging, session transcript logging, packet mirroring, customer KMS keys or immutable audit retention.
- Narrow security scan scope; no all-policy compliance claim. Python and action dependencies can be hardened further with hashes/immutable pins.
- Initial state is local; a lost state file can orphan resources. Remote state has a separate lifecycle and costs.
- If a deploy never reaches complete outputs, automatic removal verification cannot certify a missing inventory; manual service checks are required after Terraform destroy.

Optional next iterations: a dedicated versioned remote-state bootstrap; reproducible image build and patch tests; Resolver query logs; scoped CloudTrail S3 data events; Session Manager transcript logging with the extra endpoint/IAM design; TLS/internal certificates; multi-AZ workloads with a revised cost model; Reachability Analyzer (billed analyses); automated incident report summaries from actual evidence. Each should be an explicit, costed change rather than silently expanding this lab.
