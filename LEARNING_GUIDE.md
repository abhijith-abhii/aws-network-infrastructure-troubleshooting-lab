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

1. **What topology is modeled?** Terraform describes segmented private AWS networking, peering, access through Systems Manager and logging. Diagnostic exercises distinguish configuration errors from connectivity symptoms.

2. **Why use mock-provider tests?** They check resource relationships and configuration invariants without provisioning AWS resources. They avoid costs but cannot prove actual packet delivery or IAM behavior in a live account.

3. **What was actually executed?** Terraform formatting, initialization, validation and twelve mock tests, plus sixteen Python checks. The complete credential-free static CI workflow also passed.

4. **Why prefer private instances and SSM?** The design avoids exposing instance management ports directly to the internet. SSM still requires correct roles, endpoint reachability and service permissions.

5. **What remains before an AWS deployment?** Review account-specific inputs, budgets, region availability and permissions, then apply only with cost approval. No AWS deployment or real outage recovery is claimed here.

## Independent exercise

Add a mocked assertion for an allowed security-group port and explain what it cannot prove about live routing.

Write down the expected behavior before editing. Add a meaningful regression check, run the existing suite, and describe what changed in your own words.

## Contribution and resume guidance

The implementation was developed with substantial AI assistance under Abhijith Viswanathan's direction. The verified contribution is the working artifact and the learning work actually completed, not invented employment or adoption.

Suggested factual bullet after personally validating the demo:

- Validated segmented AWS network infrastructure with Terraform, twelve mock-provider checks and sixteen Python checks; documented diagnostics without provisioning paid resources.

Use [VERIFICATION.md](VERIFICATION.md) to add only measured numbers. Do not claim production traffic, users, savings, upstream acceptance or cloud deployment without corresponding evidence.
