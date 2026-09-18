#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
for tool in terraform python3 ruff checkov; do
  command -v "$tool" >/dev/null || { echo "Missing: $tool" >&2; exit 1; }
done
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init -backend=false -input=false -lockfile=readonly
terraform -chdir=terraform validate
terraform -chdir=terraform test
ruff check scripts tests
python3 -B -m unittest discover -s tests -v
for script in scripts/*.sh; do bash -n "$script"; done
checkov --config-file .checkov.yaml
