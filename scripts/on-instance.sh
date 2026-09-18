#!/usr/bin/env bash
# Run inside a lab Session Manager shell; read-only diagnostics, except temporary curl connection.
set -Eeuo pipefail
LAB_HOST=${1:-app.aws-netlab.internal}
if [[ ! "$LAB_HOST" =~ ^app\.[a-z][a-z0-9-]{2,19}\.internal$ ]]; then
  echo 'Expected app.<lab-id>.internal' >&2
  exit 2
fi
date -u
ip -4 address
ip route
ip route get 10.20.10.10
ss -ltn
ss -tn
dig +time=2 +tries=1 "$LAB_HOST" A
set +e
curl --noproxy '*' -v --connect-timeout 4 --max-time 8 "http://$LAB_HOST/"
RESULT=$?
set -e
printf 'curl_exit_code=%s\n' "$RESULT"
# Retain diagnostic output even when the selected fault intentionally breaks curl.
