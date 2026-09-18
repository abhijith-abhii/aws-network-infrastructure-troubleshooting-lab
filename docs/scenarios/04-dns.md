# Private application record missing

Run from a healthy deployment. No other fault may be active. The commands below are expected procedures; live results must be collected in your AWS account. Prepare the workstation diagnostic variables using [the diagnostic reference](../diagnostics.md). Linux commands belong in the indicated Session Manager shell, not your workstation.

## Baseline, injection and evidence

```bash
python3 scripts/lab.py test
python3 scripts/lab.py inject dns --approve
python3 scripts/lab.py test --expect dns
python3 scripts/lab.py evidence
```

`inject` performs the healthy baseline check itself, prints the Terraform plan, and rejects changes outside this scenario's one resource. It polls the expected fault for up to three minutes of propagation. Stop and investigate an unexpected test result; a different failure is not a successful exercise.

The baseline private record `app.aws-netlab.internal A 10.20.10.10` is visible in both VPCs and has a 5-second positive TTL. A custom lab ID changes the zone and hostname accordingly.

**One fault:** Terraform removes `aws_route53_record.app[0]`. The private hosted zone, both associations, AmazonProvidedDNS, and AWS endpoint private DNS remain intact.

**Expected symptoms:** `dig` eventually reports `status: NXDOMAIN`; hostname curl fails with exit 6, while direct-IP curl returns the healthy body. Both S3 tests and SSM continue to work. `dig` itself often exits zero for NXDOMAIN, so inspect the status/answer instead of the exit code.

## Investigation

1. On the client, compare name and IP requests:

   ```bash
   dig +time=2 +tries=1 app.aws-netlab.internal A
   curl --noproxy '*' -v --connect-timeout 4 --max-time 8 http://app.aws-netlab.internal/
   curl --noproxy '*' -fsS --connect-timeout 4 --max-time 8 http://10.20.10.10/
   curl --noproxy '*' -fsS --connect-timeout 4 --max-time 8 --resolve app.aws-netlab.internal:80:10.20.10.10 http://app.aws-netlab.internal/
   ```

   The last command bypasses DNS for that request. Success isolates resolution from the application/transport path; it is not a DNS test.
2. Query `dig ssm.us-east-1.amazonaws.com` (adjust Region) and inspect `/etc/resolv.conf`. Healthy management-name resolution shows why this isn't a global resolver outage. Do not modify resolv.conf or VPC DHCP options during this scenario.
3. On the workstation:

   ```bash
   aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID"
   aws route53 get-hosted-zone --id "$ZONE_ID"
   ```

   The zone's NS/SOA records and VPC associations remain; the `app` A record is absent. Record the actual query time, response status and TTL/cache context.
4. Do not look for DNS answers in Flow Logs. Queries to the built-in resolver are excluded from normal VPC Flow Logs. Route 53 configuration and `dig` output are the evidence here. Optional Resolver query logging is a separate enhancement, not implemented.
5. Restore the record. Positive TTL is short, but an NXDOMAIN response can remain negatively cached according to the zone SOA (commonly 900 seconds). Check it with `dig aws-netlab.internal SOA`. The restore tests poll up to 17 minutes; do not reintroduce the fault while waiting.

**Root cause:** the exact application A record is missing from an authoritative private zone. Repair recreates it; routes and security rules were not broken. Existing shells remain manageable. Flushing a guest cache cannot flush the AWS resolver's negative cache.

## Repair and recovery verification

```bash
python3 scripts/lab.py restore --approve
python3 scripts/lab.py test
python3 scripts/lab.py evidence
```

Restoration reapplies `scenario=baseline` through Terraform from your workstation, then verifies HTTP by name/IP, DNS, object reads from both nodes, local service health and the two denied-traffic controls. The management path is designed to survive this fault. If management is unexpectedly lost, the same control-plane repair still runs; use [operations](../operations.md) if unrelated drift is detected. Do not inject the next fault until baseline testing succeeds.

## Incident report template

```text
Personal lab incident: dns
Date/time (UTC), Region, AMI, provider version: [fill in]
Scope and intentionally injected change: [resource/rule/policy]
Observed impact and healthy controls: [actual results]
Hypotheses and investigation sequence: [commands, timestamps]
Evidence: [redacted file/screenshot/query references]
Root cause supported by evidence: [explain the failing layer]
Repair and measured recovery time: [steps; measure, do not estimate]
Recovery and denied-access checks: [actual results]
Prevention / production improvement: [specific proposed control]
```
