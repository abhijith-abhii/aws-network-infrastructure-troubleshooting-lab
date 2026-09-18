# Missing peer route

Run from a healthy deployment. No other fault may be active. The commands below are expected procedures; live results must be collected in your AWS account. Prepare the workstation diagnostic variables using [the diagnostic reference](../diagnostics.md). Linux commands belong in the indicated Session Manager shell, not your workstation.

## Baseline, injection and evidence

```bash
python3 scripts/lab.py test
python3 scripts/lab.py inject routing --approve
python3 scripts/lab.py test --expect routing
python3 scripts/lab.py evidence
```

`inject` performs the healthy baseline check itself, prints the Terraform plan, and rejects changes outside this scenario's one resource. It polls the expected fault for up to three minutes of propagation. Stop and investigate an unexpected test result; a different failure is not a successful exercise.

The baseline client request to `http://10.20.10.10/` returns `AWS network lab: HTTP healthy`. Both private route tables contain their opposite workload /24 route.

**One fault:** Terraform removes `module.peering.aws_route.client_to_server[0]`, the client's `10.20.10.0/24 → pcx` route. The server's reverse route is retained. No SG, ACL, DNS, S3 or SSM endpoint changes are intended.

**Expected symptoms:** direct-IP and hostname HTTP requests time out (curl exit 28). DNS still answers `10.20.10.10`. Both S3 reads, server loopback HTTP, and Session Manager stay healthy.

## Investigation

1. On the client, separate name resolution from reachability:

   ```bash
   dig +time=2 +tries=1 app.aws-netlab.internal A
   curl --noproxy '*' -v --connect-timeout 4 --max-time 8 http://10.20.10.10/
   ip route
   ip route get 10.20.10.10
   ```

   Expect a DNS answer and an HTTP timeout. The guest route can still show its normal virtual gateway; it cannot display AWS VPC route-table entries.

2. On the server, `curl -fsS http://127.0.0.1/` and `sudo ss -ltnp` establish that the service listens and responds locally.
3. From the workstation, inspect both actual route tables:

   ```bash
   aws ec2 describe-route-tables --route-table-ids "$CLIENT_RT" "$SERVER_RT"
   ```

   Find the missing forward `/24` route, the healthy reverse `/24` route, and the unchanged local/S3 routes. Confirm the peering connection is active in the VPC console or `describe-vpc-peering-connections` using the inventory ID.
4. Compare the Terraform plan and captured `routes.json`. Look for recent HTTP flows at the two workload ENIs, but do not assume missing routes must produce a particular REJECT record. The absence of a server record alone is inconclusive because delivery is delayed and Flow Logs are best-effort.
5. Rule out DNS and application failure using the healthy controls. The control-plane route evidence localizes this exercise's root cause.

**Root cause:** the client VPC router has no destination route to the peer's private workload subnet. Repair recreates that one route; the host OS routing table does not need editing.

## Repair and recovery verification

```bash
python3 scripts/lab.py restore --approve
python3 scripts/lab.py test
python3 scripts/lab.py evidence
```

Restoration reapplies `scenario=baseline` through Terraform from your workstation, then verifies HTTP by name/IP, DNS, object reads from both nodes, local service health and the two denied-traffic controls. The management path is designed to survive this fault. If management is unexpectedly lost, the same control-plane repair still runs; use [operations](../operations.md) if unrelated drift is detected. Do not inject the next fault until baseline testing succeeds.

## Incident report template

```text
Personal lab incident: routing
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
