# Diagnostic commands and evidence limits

For workstation examples in the scenario guides, create a quoted environment from the actual Terraform inventory:

```bash
python3 scripts/lab.py inventory > .lab/view.json
python3 scripts/inventory-env.py .lab/view.json > .lab/diagnostics.env
source .lab/diagnostics.env
```

This defines `AWS_REGION`, `CLIENT_ID`, `SERVER_ID`, `CLIENT_RT`, `SERVER_RT`, `CLIENT_SG`, `SERVER_SG`, `SERVER_ACL`, `CLIENT_S3_EP`, `SERVER_S3_EP`, `BUCKET`, `OBJECT_KEY`, `HOSTNAME_LAB`, `ZONE_ID`, and `LOG_GROUP`. Run this only on a trusted local inventory; the helper shell-quotes every value. `AWS_PROFILE` remains your SSO profile. Never substitute resource IDs from unrelated workloads.

Use `python3 scripts/lab.py session client` or `session server` for Linux commands. Paste the actual hostname/bucket shown by `inventory` where a guide uses variables; workstation environment is not automatically transferred into a Session Manager shell. Default hostname: `app.aws-netlab.internal`. The Linux helper can be copied into a session for a general snapshot, or use automated `evidence` collection.

| Command | What it establishes | What it does not establish |
|---|---|---|
| `curl --noproxy '*' -v --connect-timeout 4 --max-time 8 http://10.20.10.10/` | TCP/application response or failure stage | Timeout alone doesn't distinguish route, SG, NACL, host firewall or application hang |
| `curl --resolve app.aws-netlab.internal:80:10.20.10.10 ...` | HTTP using a chosen IP with the expected Host header | Does not test actual DNS |
| `dig +time=2 +tries=1 app.aws-netlab.internal A` | Resolver status, answer and TTL | Exit code zero alone doesn't imply a DNS answer; NXDOMAIN usually exits zero |
| `ip route` / `ip route get 10.20.10.10` | Guest routing to VPC virtual gateway | Cannot show AWS route-table/peering entries; guest route can look normal while VPC route is missing |
| `ss -ltnp` on server | Listening socket on TCP/80 | Doesn't prove remote reachability |
| `ss -tn` during an HTTP request | Socket state such as SYN-SENT | Cannot identify which AWS control dropped a packet |
| `systemctl status netlab-http` and `journalctl -u netlab-http` | Process/service status and requests reaching application | An absent access-log request doesn't localize the drop |
| `aws s3api get-object ...` | Signed, authorized object read when body matches | 403 alone doesn't identify which policy denied it; requires policy comparison |
| `describe-route-tables`, `describe-security-groups`, `describe-network-acls` | Actual AWS control-plane configuration | Doesn't prove a particular packet traversed the intended path |
| CloudWatch VPC Flow Logs | Aggregated 5-tuple/protocol/action/bytes for captured IP flows | Not a packet capture; no HTTP body, DNS answer or IAM denial reason; no rule ID |

Client manual baseline:

```bash
curl --noproxy '*' -fsS --connect-timeout 4 --max-time 8 http://10.20.10.10/
curl --noproxy '*' -fsS --connect-timeout 4 --max-time 8 http://app.aws-netlab.internal/
dig +time=2 +tries=1 app.aws-netlab.internal A
ip route get 10.20.10.10
# Replace bucket if you used a custom lab ID/Region/account.
aws s3api get-object --region us-east-1 --bucket YOUR_LAB_BUCKET --key test/hello.txt /tmp/test-object.txt
cat /tmp/test-object.txt
```

Expected baseline body patterns: `AWS network lab: HTTP healthy` and `AWS network lab: S3 healthy`. On the server, `curl http://127.0.0.1/` must return the HTTP body and `sudo ss -ltnp` should show the Python listener at `0.0.0.0:80`.

## Proving the private S3 path

1. Run the successful GetObject test **from each instance**, not the workstation.
2. Inspect each private route table. Its AWS-managed `DestinationPrefixListId` for regional S3 targets that VPC's `vpce-...`. There is no `0.0.0.0/0` route.
3. Inspect the S3 endpoint's route-table association, gateway type and available state. Compare `describe-prefix-lists` with the S3 address returned by `dig` if helpful.
4. Review the bucket policy: the instance role is denied GetObject unless `aws:SourceVpce` is one of these two endpoints. IAM allows only this object and regional package downloads. Success under that constraint is stronger evidence than a public-looking DNS address.
5. During the S3 fault, only the client endpoint's explicit deny is introduced; the server still reads the same object and HTTP remains healthy. Collect before/after policies and command results.

Gateway endpoint S3 hostnames can resolve to **public S3 IP addresses**. The prefix-list route sends those destinations over AWS's gateway endpoint; private connectivity does not require an RFC1918 answer. `traceroute` or Flow Logs alone does not prove the endpoint authorization path. There is no dedicated S3 endpoint ENI for a gateway endpoint.
