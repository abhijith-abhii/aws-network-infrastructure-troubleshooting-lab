# Security decisions and tradeoffs

This is a personal lab with narrow traffic paths, not a production security certification.

| Decision | Benefit | Tradeoff / limit |
|---|---|---|
| Private EC2, no SSH keys, no inbound administration | Removes exposed administrative ports | Operator SSM IAM remains powerful; Run Command executes as root |
| Local SSM endpoints in each VPC | Management does not depend on peering | Four billed endpoint-AZ hours for each clock hour |
| Modern standard AL2023 AMI + S3 packages | Bootstrap without NAT or temporary public IPs | Requires regional repository access and current Agent; no external packages |
| Exact client/server /32 SG rules | Restricts HTTP to the exercise | Fixed IP assignment must stay consistent across code/docs |
| NACL TCP 80/443 egress and ephemeral ingress from any IPv4 | Handles changing S3 public ranges without brittle CIDR copying | Broad at subnet layer; SG prefix list and endpoint authorization narrow it |
| SSE-S3 bucket + encrypted gp3 + IMDSv2 | Encryption at rest and metadata token enforcement | AWS-managed encryption, no customer-managed key separation |
| CloudWatch service encryption at rest | Encrypted Flow Logs without a customer KMS key | No custom key rotation/revocation control |
| Interface endpoint default policy | Straightforward EC2/SSM compatibility | Endpoint policy is not an extra identity restriction; SG and instance IAM still enforce access |
| S3 endpoint allow-list and GetObject IAM | Lab role cannot write objects or browse unrelated buckets | AL2023 regional hash wildcard and AWS SSM regional downloads are permitted |
| Bucket TLS deny + instance-role SourceVpce deny | Instance reads require TLS and one of this lab's endpoints | Trusted deployment/admin identity can manage/read from the workstation; the path constraint deliberately applies to the EC2 roles |
| HTTP on TCP/80 | Makes basic transport diagnosis clear | No TLS for the harmless private test page; do not carry secrets |
| Short Flow Log retention; delete on teardown | Limits ongoing storage and stale lab data | Collect evidence before teardown; no immutable audit archive |
| Unversioned test-object bucket; no server access logging | Simple, low-volume disposable fixture | No recovery history or S3 data event audit; Terraform deletion is intentional |

S3 policy evaluation is layered: the role must allow the object, the endpoint must permit the request, and an applicable explicit deny overrides those allows. The bucket does not make an object public. Object ownership is bucket-enforced and all four S3 public-access-block settings are enabled. The bucket's instance-role endpoint condition avoids locking Terraform's workstation refresh and teardown out of its own fixture.

No credentials or secret application data are embedded in Terraform/user data. State, plans, local variable files, command output, and logs can expose account IDs and resource topology, so they are ignored by Git. State is still readable locally: secure your workstation and disk. Never add `.aws/`, tokens, keys, `.lab/`, `.terraform/`, raw state, or unredacted evidence to the portfolio.

## CI security gate

Checkov is pinned in `requirements-dev.txt`. `.checkov.yaml` runs a documented focused set: encrypted EBS and S3; private S3 ACL/public-access configuration; SG descriptions and no public SSH/RDP; required IMDSv2; no public instance IP; EBS optimization. This is an intentionally scoped gate, not a claim that every Checkov policy passes. It complements Terraform schema validation, mocked plan assertions and automation safety tests.

To inspect the full policy catalogue, run outside the repository directory (so the selected config is not automatically loaded):

```bash
# Replace REPO with this repository's absolute path.
cd /tmp
CHECKOV_SKIP_DOWNLOAD=true checkov --directory REPO/terraform --framework terraform --download-external-modules false
```

Expect production-oriented recommendations such as S3 versioning/access logging, customer-managed keys, detailed EC2 monitoring, and longer log retention. Review those in the context of this disposable lab rather than silently claiming they were remediated. CI has read-only GitHub permissions, no OIDC grants, no AWS credentials, and no deployment step. Action major tags are convenient but not immutable; pin reviewed action commit SHAs for stronger supply-chain controls.
