# Network Foundry

Reproduce a segmented AWS network safely for **cloud engineering learners**.

Cloud/DevOps topic selected with explicit user authorization after source verification; it is not attributed to an unseen Instagram slide.

> Local portfolio implementation developed with Codex assistance. Measured results and limitations are documented; no production adoption, revenue or hiring outcome is claimed.

## What works

- Existing Terraform modules
- mock-provider tests
- plan guidance
- local validation

[Demonstration guide](LEARNING_GUIDE.md) · [Verification notes](VERIFICATION.md) · [Learning and interview guide](LEARNING_GUIDE.md)

## Start

Python 3.12 is the validated Python runtime. Run commands from this repository directory. Windows users activate `.venv\Scripts\activate` instead of `source`.

```sh
cd terraform
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
terraform test
# These tests use mock providers. Do not run terraform apply without cost approval.
```

## Demonstration

Run terraform init -backend=false, terraform fmt -check -recursive, terraform validate and terraform test from terraform/. Inspect the test evidence and choose a documented fault scenario without applying to AWS.

## Architecture and decisions

Terraform root configuration → reusable modules → mock-provider tests → optional user-authorized AWS deployment.

Stack: Terraform · Python.

1. Separate networking, compute, peering, endpoint and logging concerns into Terraform modules.
2. Use mock providers to exercise topology and fault scenarios without creating billable AWS resources.
3. Keep expected-account checks and limited private networking in the real configuration.

## Verification

```sh
python -m unittest discover -s tests -v
# Also run the Terraform checks above.
```

See [VERIFICATION.md](VERIFICATION.md) for actual executed checks, setup verification, model/data results and any outstanding environment limitations. The [recorded CI runs](reports/ci-verification.json) passed for the linked source revision.

## Data and attribution

AWS configuration; no paid apply. See [DATA_AND_SOURCES.md](DATA_AND_SOURCES.md) for provenance and usage notes. Original project code is MIT unless a preserved source file or dependency states otherwise. Model and third-party data licenses remain separate.

## Limitations and next improvement

Terraform configuration and mock-provider behavior are validated; no AWS deployment is claimed. A real apply requires user-supplied account/region/AMI settings and explicit cost approval. Mock tests cannot establish IAM service behavior or network reachability.

Suggested extension: Add a mocked assertion for an allowed security-group port and explain what it cannot prove about live routing.

## Honest portfolio use

This implementation and documentation were developed with substantial Codex assistance. Before presenting it, run the demonstration, explain the design choices, and complete the suggested independent modification. Do not describe generated code as work experience, an accepted upstream contribution, or a deployed production service.
