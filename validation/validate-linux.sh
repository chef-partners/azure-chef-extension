#!/bin/bash
# Validates the Azure Chef Extension Linux configuration and install flow.
# Usage: bash validation/validate-linux.sh [--license-key <key>]

set -euo pipefail

LICENSE_KEY=""
overall=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --license-key) LICENSE_KEY="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; overall=1; }

echo ""
echo "=== Azure Chef Extension Linux Validation ==="

# 1. Required files
for f in "ChefExtensionHandler/bin/chef-install.sh" "ChefExtensionHandler/bin/shared.sh"; do
  if [ -f "$f" ]; then
    pass "Required file exists: $f"
  else
    fail "Required file missing: $f"
  fi
done

# 2. chef_license_key plumbing in shared.sh
if grep -q "read_chef_license_key" ChefExtensionHandler/bin/shared.sh; then
  pass "shared.sh contains read_chef_license_key"
else
  fail "shared.sh missing read_chef_license_key"
fi

if grep -q "log_license_key_status" ChefExtensionHandler/bin/shared.sh; then
  pass "shared.sh contains log_license_key_status"
else
  fail "shared.sh missing log_license_key_status"
fi

# 3. chef-install.sh calls read_chef_license_key
if grep -q "read_chef_license_key" ChefExtensionHandler/bin/chef-install.sh; then
  pass "chef-install.sh calls read_chef_license_key"
else
  fail "chef-install.sh missing read_chef_license_key call"
fi

# 4. Validate license key format if supplied
if [ -n "$LICENSE_KEY" ]; then
  key_len=${#LICENSE_KEY}
  if [ "$key_len" -ge 10 ]; then
    pass "License key length >= 10 chars"
  else
    fail "License key too short (< 10 chars)"
  fi
fi

echo ""
if [ "$overall" -eq 0 ]; then
  echo "All validation checks passed."
  exit 0
else
  echo "One or more validation checks FAILED."
  exit 1
fi
