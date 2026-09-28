# Network Foundry — learning guide

## What it does

Reproduce a segmented AWS network safely. The intended user is cloud engineering learners. Terraform root configuration → reusable modules → mock-provider tests → optional user-authorized AWS deployment.

## Run and demonstrate

Follow the README installation block, then: Run terraform init -backend=false, terraform fmt -check -recursive, terraform validate and terraform test from terraform/. Inspect the test evidence and choose a documented fault scenario without applying to AWS.

## Important files

- `terraform/main.tf` — module composition.
- `terraform/modules/` — individual infrastructure concerns.
- `terraform/tests/` — mocked plans and assertions.
- `tests/test_lab.py` — Python lab checks.

## Three engineering decisions

1. Separate networking, compute, peering, endpoint and logging concerns into Terraform modules.
2. Use mock providers to exercise topology and fault scenarios without creating billable AWS resources.
3. Keep expected-account checks and limited private networking in the real configuration.

## Five interview questions

1. **What problem does this project solve, and what is its unit of work?** Explain reproduce a segmented aws network safely, identify cloud engineering learners as the audience, and trace one concrete example through the files above. Use the demonstration output rather than hypothetical impact.
2. **Why did you choose the first design decision?** Separate networking, compute, peering, endpoint and logging concerns into Terraform modules. Show the corresponding implementation and a test that would fail if that property were removed.
3. **How do you protect correctness when inputs or execution change?** Use mock providers to exercise topology and fault scenarios without creating billable AWS resources. Explain the relevant invalid-input or edge-case test and distinguish a checked property from an untested assumption.
4. **How do you make results inspectable and reproducible?** Keep expected-account checks and limited private networking in the real configuration. Point to actual outputs and recorded commands. Explain why a successful example is weaker evidence than a tested boundary or independently reconciled total.
5. **What would you improve before real deployment or real-data use?** Terraform configuration and mock-provider behavior are validated; no AWS deployment is claimed. A real apply requires user-supplied account/region/AMI settings and explicit cost approval. Mock tests cannot establish IAM service behavior or network reachability. Choose one limitation, describe the missing evidence, and propose a measurable acceptance check rather than promising production readiness.

## Independent exercise

Add a mocked assertion for an allowed security-group port and explain what it cannot prove about live routing.

Write down the expected behavior before editing. Add a meaningful regression check, run the existing suite, and describe what changed in your own words.

## Contribution and resume guidance

The implementation was developed with substantial AI assistance under Abhijith Viswanathan's direction. The verified contribution is the working artifact and the learning work actually completed, not invented employment or adoption.

Suggested factual bullet after personally validating the demo:

- Implemented and validated reproduce a segmented aws network safely using Terraform · Python, with existing terraform modules and documented correctness checks and limitations.

Use [VERIFICATION.md](VERIFICATION.md) to add only measured numbers. Do not claim production traffic, users, savings, upstream acceptance or cloud deployment without corresponding evidence.
