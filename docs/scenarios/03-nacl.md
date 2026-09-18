# Stateless HTTP return traffic denied

Run from a healthy deployment. No other fault may be active. The commands below are expected procedures; live results must be collected in your AWS account. Prepare the workstation diagnostic variables using [the diagnostic reference](../diagnostics.md). Linux commands belong in the indicated Session Manager shell, not your workstation.

## Baseline, injection and evidence

```bash
python3 scripts/lab.py test
python3 scripts/lab.py inject nacl --approve
python3 scripts/lab.py test --expect nacl
python3 scripts/lab.py evidence
```

`inject` performs the healthy baseline check itself, prints the Terraform plan, and rejects changes outside this scenario's one resource. It polls the expected fault for up to three minutes of propagation. Stop and investigate an unexpected test result; a different failure is not a successful exercise.

The healthy connection is `client:ephemeral → server:80`, followed by `server:80 → client:ephemeral`. Baseline server ACL rule 140 permits outbound TCP/1024–65535 to `10.10.10.10/32`.

**One fault:** Terraform inserts `module.network["server"].aws_network_acl_rule.fault_return[0]`, outbound rule 90 denying TCP/1024–65535 to that exact client. It does not remove the ordinary HTTP ingress rule or change either SG.

**Expected symptoms:** HTTP by IP and name times out (curl 28), although the server listens and the initial request direction is allowed. DNS, S3 and SSM stay healthy. The SYN-ACK is return traffic too; do not assume the three-way handshake completes or that the HTTP request reaches the application.

## Investigation

1. Generate a fresh client connection with a known ephemeral source range:

   ```bash
   curl --noproxy '*' -v --local-port 40000-40100 --connect-timeout 4 --max-time 8 http://10.20.10.10/
   ip route get 10.20.10.10
   ```

   `ss -tn` in another shell during the attempt may show `SYN-SENT`; this is an expected pattern, not guaranteed after the short timeout.
2. On the server, verify `sudo ss -ltnp`, `systemctl status netlab-http`, and loopback HTTP. Correct application state does not prove that its replies can leave the subnet.
3. From the workstation, confirm routes and TCP/80 SG ingress are healthy, then inspect the actual subnet-associated ACL:

   ```bash
   aws ec2 describe-network-acls --network-acl-ids "$SERVER_ACL"
   aws ec2 describe-security-groups --group-ids "$SERVER_SG"
   aws ec2 describe-route-tables --route-table-ids "$CLIENT_RT" "$SERVER_RT"
   ```

   Read the `Egress` flag, destination CIDR, port range and rule numbers. Rule 90 matches return destination ports before allow rule 140. Removing an ingress rule would be a different experiment.
4. Query both HTTP directions. Captured server-to-client records can show REJECT with source port 80 and destination port 40000–40100. Initial traffic may show ACCEPT. These are evidence patterns, not a guarantee of a particular record order; use the documented [AWS Flow Log examples](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-records-examples.html) to understand directionality.
5. Explain why SG connection tracking cannot override a stateless ACL deny. Record the exact winning ACL rule as the configuration evidence.

**Root cause:** the outbound subnet ACL blocks the TCP response destination port, despite permitting inbound port 80. Repair removes only the exercise deny, revealing existing allow rule 140 again. The CIDR is the peer client /32, so local endpoint management traffic is unaffected.

## Repair and recovery verification

```bash
python3 scripts/lab.py restore --approve
python3 scripts/lab.py test
python3 scripts/lab.py evidence
```

Restoration reapplies `scenario=baseline` through Terraform from your workstation, then verifies HTTP by name/IP, DNS, object reads from both nodes, local service health and the two denied-traffic controls. The management path is designed to survive this fault. If management is unexpectedly lost, the same control-plane repair still runs; use [operations](../operations.md) if unrelated drift is detected. Do not inject the next fault until baseline testing succeeds.

## Incident report template

```text
Personal lab incident: nacl
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
