# One S3 endpoint policy denies the object

Run from a healthy deployment. No other fault may be active. The commands below are expected procedures; live results must be collected in your AWS account. Prepare the workstation diagnostic variables using [the diagnostic reference](../diagnostics.md). Linux commands belong in the indicated Session Manager shell, not your workstation.

## Baseline, injection and evidence

```bash
python3 scripts/lab.py test
python3 scripts/lab.py inject s3-policy --approve
python3 scripts/lab.py test --expect s3-policy
python3 scripts/lab.py evidence
```

`inject` performs the healthy baseline check itself, prints the Terraform plan, and rejects changes outside this scenario's one resource. It polls the expected fault for up to three minutes of propagation. Stop and investigate an unexpected test result; a different failure is not a successful exercise.

The baseline exact object read succeeds from **both** instances and produces `AWS network lab: S3 healthy`. The bucket is private; each instance role allows GetObject on the test key. The bucket policy restricts instance-role reads to the two lab endpoints and requires TLS.

**One fault:** Terraform updates only `module.endpoints["client"].aws_vpc_endpoint.s3.policy`, adding `LabFaultDenyTestObject` for `s3:GetObject` on the exact test-object ARN. The AL2023/agent-download allows, server endpoint, bucket policy, IAM role and route stay unchanged.

**Expected symptoms:** client GetObject reports `AccessDenied` (typically CLI exit 254/HTTP 403), not a connect timeout. The server still reads the same object. Both HTTP tests, DNS and SSM remain healthy. AWS enhanced access-denied explanations are not guaranteed to identify endpoint policy as the reason.

## Investigation

1. Run the exact command in the client session, replacing `YOUR_LAB_BUCKET` using the real inventory:

   ```bash
   aws s3api get-object --region us-east-1 --bucket YOUR_LAB_BUCKET --key test/hello.txt /tmp/test-object.txt --cli-connect-timeout 4 --cli-read-timeout 10
   ```

   Capture stderr, return code and UTC time. Do not infer that the bucket/object is missing from this response. Use the same command in the server session as a control; it must still succeed.
2. Verify HTTP and DNS remain healthy. An HTTPS response from S3 already distinguishes authorization failure from an unreachable service, but it doesn't localize the denying policy.
3. Inspect both endpoints on the workstation:

   ```bash
   aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$CLIENT_S3_EP" "$SERVER_S3_EP"
   aws ec2 describe-route-tables --route-table-ids "$CLIENT_RT" "$SERVER_RT"
   aws s3api get-bucket-policy --bucket "$BUCKET"
   ```

   Compare endpoint `PolicyDocument` values. Only client has the explicit deny for the key. `evidence` also saves each instance's inline object-read IAM policy; confirm it did not change.
4. Reconstruct the authorization chain: role allow + endpoint allow + applicable bucket constraints, then the fault's overriding explicit deny. Endpoint policies do not grant access that an IAM or bucket policy denies.
5. Flow Logs can show network traffic to S3 accepted while the object request is denied. They **cannot identify IAM/endpoint policy denial**. No S3 data-event CloudTrail is configured here; do not claim an event exists. Use the controlled plan, actual policies, client stderr and successful server control as evidence.
6. Restore baseline and repeat the exact object reads from both instances. Compare file contents, not just command exit status.

**Root cause:** the client's S3 gateway endpoint evaluates a deliberate object-specific explicit deny. Repair removes that statement without changing routes, bucket visibility, credentials or management paths. Avoid `aws sts get-caller-identity` on an instance: this lab has no STS interface endpoint or internet route. Check the instance profile from the workstation instead.

## Repair and recovery verification

```bash
python3 scripts/lab.py restore --approve
python3 scripts/lab.py test
python3 scripts/lab.py evidence
```

Restoration reapplies `scenario=baseline` through Terraform from your workstation, then verifies HTTP by name/IP, DNS, object reads from both nodes, local service health and the two denied-traffic controls. The management path is designed to survive this fault. If management is unexpectedly lost, the same control-plane repair still runs; use [operations](../operations.md) if unrelated drift is detected. Do not inject the next fault until baseline testing succeeds.

## Incident report template

```text
Personal lab incident: s3-policy
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
