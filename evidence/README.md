# Evidence checklist (no live evidence supplied)

Everything else in this directory is ignored by Git. Automated tests/evidence collection write timestamped JSON here after deployment. Synthetic unit-test fixtures are not AWS evidence. No screenshots, working deployment, recovery time, performance result or AWS deletion has been claimed for this delivery.

Capture and redact before publishing:

- [ ] UTC date, Region/AZ, pinned AMI, SSM Agent version, Terraform/provider versions.
- [ ] Diagram and subnet/route views showing two private instances and no public IPs.
- [ ] SSM sessions to both instances, without exposing credentials/session tokens.
- [ ] Baseline HTTP by IP/name, `dig`, both S3 bodies, local listener and denied-access checks.
- [ ] S3 private route-table associations, endpoint policy and role-specific SourceVpce restriction.
- [ ] Shared Flow Log group and actual OK records from both workload ENIs.
- [ ] For each of five faults: one-resource plan, failing test, healthy control, relevant AWS configuration, diagnostic timeline and completed incident report.
- [ ] Restoration test/evidence after every scenario; no unverified recovery claims.
- [ ] Example Logs Insights screenshot with the actual time window and fields.
- [ ] Destroy plan, successful independent removal check, empty state and later Billing review.

`lab.py evidence` collects routes, workload SGs, private ACLs, S3 endpoint policies, bucket policy, inline object-read IAM policies, DNS records, delivery status, recent Flow Logs, Linux routes/sockets/DNS/SSM status, bootstrap logs and HTTP service logs. Some command output is capped by SSM; long forensic captures need a separately scoped storage/logging design. It intentionally does not enable account-wide CloudTrail or upload files elsewhere.

Keep raw evidence local. Redact account IDs, identity ARNs, bucket names, instance IDs, private hostnames as appropriate, command IDs and any sensitive data. Never publish `.lab/`, plans, state, SSO credentials, cookies or session transcripts containing secrets. Put only consciously reviewed screenshots/reports into a separate portfolio folder and add them explicitly to Git.
