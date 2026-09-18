# Testing contract

## Offline checks

Run `./scripts/static-checks.sh` after installing `requirements-dev.txt` and Terraform. No AWS credentials are required. Terraform must download its provider on first initialization; “offline” here means no AWS deployment, not necessarily no internet downloads.

- Terraform formatting and provider-schema validation.
- Twelve Terraform mock runs: compute security and SG fault, endpoint policy and SSM continuity, ACL direction/order, route removal, private DNS removal and rejection of invalid scenarios. Root DNS tests use **mocked apply phases** to resolve resource IDs; no real AWS resources are created. Module tests use mocked plans.
- Python safety/error-classification contracts, including account mismatch, unrelated drift/replacement, wrong failure types, missing expected content and distinguishing access denial from resource absence.
- Python linting; Bash syntax checks, including both rendered bootstrap branches.
- Scoped Checkov security policy checks. See [security.md](security.md) for coverage and tradeoffs.

GitHub Actions runs this same script with no AWS secrets, no OIDC permission, and no deployment job. An authored workflow is not proof of a successful hosted GitHub Actions run. [Validation status](validation.md) distinguishes locally run checks from checks not yet run.

## Live integration expectations

Use a dedicated AWS deployment. These tests initiate real SSM commands; `integration --approve` changes and restores Terraform resources. Full execution is billable and must be explicitly chosen by the operator.

| Test | Baseline | Routing / SG / NACL | DNS | S3 policy |
|---|---|---|---|---|
| Client HTTP by server IP | Expected body | curl timeout 28 | Expected body | Expected body |
| Client HTTP by hostname | Expected body | curl timeout 28 | resolution error 6 | Expected body |
| Client `dig` | NOERROR + server IP | Same | NXDOMAIN | Same |
| Client GetObject | Expected body | Expected body | Expected body | AccessDenied |
| Server GetObject | Expected body | Expected body | Expected body | Expected body |
| Server loopback HTTP | Expected body | Expected body | Expected body | Expected body |
| Client TCP/22 connection probe | Timeout 28 | Timeout 28 | Timeout 28 | Timeout 28 |
| Server new HTTP to client | Timeout 28 | Timeout 28 | Timeout 28 | Timeout 28 |

The TCP/22 check uses an HTTP curl URL aimed at port 22 purely to test whether a TCP connection can be established; it does not perform an SSH login. Expected dropped connections time out before any protocol exchange. A refused connection, wrong body, general SSM error, or S3 transport timeout is **not** accepted as the intended fault.

```bash
python3 scripts/lab.py test
python3 scripts/lab.py flow-logs
python3 scripts/lab.py integration --approve
python3 scripts/lab.py destroy --approve
python3 scripts/lab.py verify-destroy
```

The scenario runner restores in a `finally` block after each fault, verifies baseline, then moves on. If restoration fails, it stops and reports the error; it does not keep injecting faults. A killed process or power failure cannot run `finally`; `restore --approve` recovers from saved local intent. Evidence files record UTC capture times, real SSM command response codes, stdout and stderr. No synthetic fixture is written as live evidence.

Flow delivery requires recent `OK` records from both workload ENIs. The check generates traffic and polls up to 15 minutes. Removal requires empty state and positive service-level removal/termination checks on saved inventory; missing permissions fail the test. Neither test is satisfied by merely having a log group or an empty locally replaced state file.

## Bounded waits

Readiness has a 20-minute polling deadline; SSM commands have an execution timeout plus a 120-second delivery/poll allowance. Connection probes use 4–8 second limits. A new fault has a three-minute propagation polling window; restoration allows 17 minutes for negative DNS cache expiry. Log delivery has 15 minutes; deletion visibility ten minutes. In-flight API/command calls can extend wall-clock time beyond a polling deadline. Every subprocess and retry loop is bounded. Checkpoints print progress so an unexpected wait can be investigated.
