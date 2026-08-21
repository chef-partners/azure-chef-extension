#!/bin/sh
# Minimal self-check for warn_if_legacy_version_needs_license (ChefExtensionHandler/bin/shared.sh).
# Asserts the extension warns when a Chef Infra Client version < 18 is
# requested without CHEF_LICENSE_KEY, and stays silent when a key is set.
#
# Usage: sh spec/shell_specs/shared_license_warning_spec.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/../../ChefExtensionHandler/bin/shared.sh"

FAILED=0

CHEF_LICENSE_KEY=""
output="$(warn_if_legacy_version_needs_license "15.17.4")"
case "$output" in
  *"require a valid license key"*) echo "[PASS] warns for version < 18 without license key" ;;
  *) echo "[FAIL] expected warning, got: ${output}"; FAILED=1 ;;
esac

CHEF_LICENSE_KEY="fake-key"
output="$(warn_if_legacy_version_needs_license "15.17.4")"
if [ -z "$output" ]; then
  echo "[PASS] no warning when CHEF_LICENSE_KEY is set"
else
  echo "[FAIL] unexpected warning with license key set: ${output}"
  FAILED=1
fi

CHEF_LICENSE_KEY=""
output="$(warn_if_legacy_version_needs_license "19.0.0")"
if [ -z "$output" ]; then
  echo "[PASS] no warning for version >= 18"
else
  echo "[FAIL] unexpected warning for version >= 18: ${output}"
  FAILED=1
fi

# log_license_key_status now hard-requires a license key unless
# CHEF_LICENSE_BYPASS="true" is explicitly set.
CHEF_LICENSE_KEY=""
CHEF_LICENSE_BYPASS=""
if output="$(log_license_key_status 2>&1)"; then
  echo "[FAIL] expected log_license_key_status to exit non-zero without a license key or bypass, got: ${output}"
  FAILED=1
else
  case "$output" in
    *"ERROR"*"chef_license_bypass"*) echo "[PASS] fails without license key when bypass is not set" ;;
    *) echo "[FAIL] expected ERROR mentioning chef_license_bypass, got: ${output}"; FAILED=1 ;;
  esac
fi

CHEF_LICENSE_KEY=""
CHEF_LICENSE_BYPASS="true"
if output="$(log_license_key_status 2>&1)"; then
  case "$output" in
    *"Falling back to omnitruck"*) echo "[PASS] falls back to omnitruck when bypass is set" ;;
    *) echo "[FAIL] expected omnitruck fallback message, got: ${output}"; FAILED=1 ;;
  esac
else
  echo "[FAIL] expected log_license_key_status to succeed when bypass is set, got: ${output}"
  FAILED=1
fi

CHEF_LICENSE_KEY="fake-key"
CHEF_LICENSE_BYPASS=""
if output="$(log_license_key_status 2>&1)"; then
  case "$output" in
    *"licensed download will be attempted"*) echo "[PASS] succeeds when license key is set" ;;
    *) echo "[FAIL] expected licensed-download message, got: ${output}"; FAILED=1 ;;
  esac
else
  echo "[FAIL] expected log_license_key_status to succeed with a license key, got: ${output}"
  FAILED=1
fi

exit "$FAILED"
