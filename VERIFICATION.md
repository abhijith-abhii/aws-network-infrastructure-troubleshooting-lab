# Network Foundry — verification

Verification date: 28 September 2026. Tests and examples were executed; they are not illustrative pass claims.

- Project checks: 16 passed.
- Dependency/setup verification: see the project-specific reproduction or runtime requirements.
- Main browser/API workflow: verified locally; actual result saved in reports/example-output.json.
- Publication: pending remote verification.
- Terraform mock tests: 12 passed

## Verification boundaries
- No AWS resources deployed; only configuration, Python and mock-provider checks executed.

## Evidence
- `reports/test-results.txt`: actual test output.
- `reports/clean-setup.json`: isolated setup result where applicable.
- `reports/publication-check.json`: credential-pattern and file audit.
- `DATA_AND_SOURCES.md`: source and license notes.
