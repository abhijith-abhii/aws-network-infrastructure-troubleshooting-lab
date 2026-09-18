# Validation record — 2026-09-18

This record describes **local checks actually executed** while building this repository. No AWS account identity, deploy, real Terraform plan, live SSM command, scenario injection, Flow Log collection, billing observation or teardown was executed. No GitHub-hosted Actions run has been claimed.

Tools: Terraform 1.14.7 (darwin_arm64), AWS provider 6.65.0, Python 3.12 for the final suite, Ruff 0.12.12, Checkov 3.2.495. The official Terraform archive checksum was checked; provider signatures/checksums were obtained for darwin_arm64 and linux_amd64. The generated lock file is included.

| Executed check | Actual result |
|---|---|
| `terraform fmt -check -recursive` | Passed |
| `terraform init -backend=false -input=false -lockfile=readonly` | Passed; provider initialization only |
| `terraform validate` | Passed against installed AWS provider schema |
| `terraform test` | **12 passed, 0 failed**, mocked providers only |
| `ruff check scripts tests` | Passed |
| `python3 -B -m unittest discover -s tests -v` | **16 passed** |
| Bash syntax checks | Passed for helper/check scripts and both bootstrap branches |
| `checkov --config-file .checkov.yaml` | **48 passed, 0 failed, 0 skipped** within selected policy scope |
| Documentation and configuration | 34 local Markdown links checked; both YAML files parsed |
| CLI help | Rendered successfully without AWS access |
| Git ignore smoke check | State/backups, real tfvars, local inventory, credentials, keys, raw evidence excluded; lock file retained |

The [captured final suite output](validation-output.txt) is actual command output with terminal color sequences and trailing blank lines removed. Earlier checks exposed syntax and mock-fixture issues; those were corrected before the passing final run. Local provider execution required permission to communicate outside the filesystem sandbox; no credentials or AWS deployment were involved.

## Still requires an authorized AWS deployment

- Actual Terraform plan/apply and account/organization permission checks.
- AMI availability, SSM Agent version, package installation, management registration and HTTP readiness.
- Real HTTP over peering and S3 reads through the gateway path.
- The five expected fault signatures, unaffected controls and restoration.
- Negative DNS cache behavior in the selected Region/image.
- Flow Log delivery from both workload ENIs and real query evidence.
- Real service-level teardown verification and delayed billing review.
- A GitHub-hosted credential-free workflow run after the repository is pushed.

The commands and assertions for these checks are implemented in [the live test contract](testing.md); they are not claimed to have passed. Publish only evidence generated from your own authorized deployment. See [README](../README.md) for exact deployment and cleanup steps.
