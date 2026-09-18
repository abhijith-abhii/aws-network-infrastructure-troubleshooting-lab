# Destination HTTP ingress removed

Run from a healthy deployment. No other fault may be active. The commands below are expected procedures; live results must be collected in your AWS account. Prepare the workstation diagnostic variables using [the diagnostic reference](../diagnostics.md). Linux commands belong in the indicated Session Manager shell, not your workstation.

## Baseline, injection and evidence

```bash
python3 scripts/lab.py test
python3 scripts/lab.py inject security-group --approve
python3 scripts/lab.py test --expect security-group
python3 scripts/lab.py evidence
```

`inject` performs the healthy baseline check itself, prints the Terraform plan, and rejects changes outside this scenario's one resource. It polls the expected fault for up to three minutes of propagation. Stop and investigate an unexpected test result; a different failure is not a successful exercise.

The baseline client returns the expected HTTP body by IP and name. The server SG has one inbound rule: TCP/80 from `10.10.10.10/32`.

**One fault:** Terraform removes `module.compute["server"].aws_vpc_security_group_ingress_rule.http[0]`. Client egress, both routes, ACLs, and management rules remain.

**Expected symptoms:** fresh HTTP connections time out (curl 28), while DNS, S3, local server HTTP and SSM succeed. Already-established SG-tracked connections may briefly behave differently; use a new curl process and source port as the automation does.

## Investigation

1. On the client, request `http://10.20.10.10/` with bounded `curl -v`. Resolve `app.aws-netlab.internal` with `dig`; the answer should remain correct.
2. On the server, inspect listener and service:

   ```bash
   sudo ss -ltnp
   sudo systemctl status netlab-http --no-pager
   curl --noproxy '*' -fsS --connect-timeout 2 --max-time 4 http://127.0.0.1/
   sudo journalctl -u netlab-http -n 20 --no-pager
   ```

   Expect local success and no application request corresponding to the dropped client attempt.
3. Inspect AWS routes, server SG and server ACL from the workstation:

   ```bash
   aws ec2 describe-route-tables --route-table-ids "$CLIENT_RT" "$SERVER_RT"
   aws ec2 describe-security-groups --group-ids "$CLIENT_SG" "$SERVER_SG"
   aws ec2 describe-network-acls --network-acl-ids "$SERVER_ACL"
   ```

   The server SG's TCP/80 ingress is absent. Routes and ACL HTTP/ephemeral allowances remain.
4. Query Flow Logs for `srcAddr=10.10.10.10`, `dstAddr=10.20.10.10`, TCP destination 80. A captured destination-side REJECT supports filtering, but Flow Logs do not name the SG or distinguish it conclusively from a NACL. Correlate with the exact configuration difference.
5. Compare baseline and fault SG evidence and the one-rule Terraform plan.

**Root cause:** the stateful server security group does not authorize new inbound TCP/80 from the client. Repair reinstates that rule. There is no need to open an ephemeral ingress range on the server SG: response permissions are stateful.

## Repair and recovery verification

```bash
python3 scripts/lab.py restore --approve
python3 scripts/lab.py test
python3 scripts/lab.py evidence
```

Restoration reapplies `scenario=baseline` through Terraform from your workstation, then verifies HTTP by name/IP, DNS, object reads from both nodes, local service health and the two denied-traffic controls. The management path is designed to survive this fault. If management is unexpectedly lost, the same control-plane repair still runs; use [operations](../operations.md) if unrelated drift is detected. Do not inject the next fault until baseline testing succeeds.

## Incident report template

```text
Personal lab incident: security-group
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
