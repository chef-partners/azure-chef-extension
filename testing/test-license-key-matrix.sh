#!/bin/bash
# Runs test-azure-extension.sh three times to exercise all license-key states:
#   1. license      — real --license-key set               → expected to PASS
#   2. no-license   — no key, no bypass                    → expected to FAIL
#                      (extension now hard-requires a license key)
#   3. bypass       — no key, --license-bypass set          → expected to PASS
#                      (explicit opt-in to the deprecated omnitruck path)
#
# Usage:
#   testing/test-license-key-matrix.sh --license-key <key> [any test-azure-extension.sh option]
#
# All options are forwarded to every run. --resource-group/--node-name are
# suffixed per-run so they don't collide. --license-key passed here is used
# only for the "license" run; the other two runs always have LICENSE_KEY
# unset regardless of .env.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── .env file loading (same convention as test-azure-extension.sh) ───────────
_env_file=""
_prev_arg=""
for _arg in "$@"; do
  [[ "${_prev_arg}" == "--env-file" ]] && { _env_file="${_arg}"; break; }
  _prev_arg="${_arg}"
done
[[ -z "${_env_file}" && -f "${SCRIPT_DIR}/.env" ]] && _env_file="${SCRIPT_DIR}/.env"
if [[ -n "${_env_file}" ]]; then
  [[ ! -f "${_env_file}" ]] && { echo "[FAIL] .env file not found: ${_env_file}" >&2; exit 1; }
  set -a; source "${_env_file}"; set +a  # shellcheck source=/dev/null
fi
unset _env_file _prev_arg _arg

MATRIX_LICENSE_KEY=""
ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --license-key) MATRIX_LICENSE_KEY="$2"; shift 2 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

[[ -z "${MATRIX_LICENSE_KEY}" ]] && MATRIX_LICENSE_KEY="${LICENSE_KEY:-}"
if [[ -z "${MATRIX_LICENSE_KEY}" ]]; then
  echo "[FAIL] --license-key <key> (or LICENSE_KEY env var) is required to test the licensed path" >&2
  exit 1
fi

BASE_RG="${RESOURCE_GROUP:-chef-ext-test-rg}"
BASE_NODE="${NODE_NAME:-az-ext-test-node}"

TOTAL_CASES=3

banner() {
  printf '\n\033[1;36m%s\033[0m\n' "════════════════════════════════════════════════════════════════════"
  printf '\033[1;36m%s\033[0m\n' "$1"
  printf '\033[1;36m%s\033[0m\n\n' "════════════════════════════════════════════════════════════════════"
}

run_case() {
  local num="$1" label="$2" expect="$3"; shift 3
  local license_args=("$@")
  banner "CASE ${num}/${TOTAL_CASES}: ${label} (expect ${expect})"
  # --license-key is parsed after test-azure-extension.sh sources .env, so it
  # reliably wins; an inherited empty LICENSE_KEY env var does not (.env
  # re-sourcing there would clobber it back to the .env value).
  local status=0
  bash "${SCRIPT_DIR}/test-azure-extension.sh" \
    --resource-group "${BASE_RG}-${label}" \
    --node-name "${BASE_NODE}-${label}" \
    ${ARGS[@]+"${ARGS[@]}"} ${license_args[@]+"${license_args[@]}"} || status=$?

  if [[ "${expect}" == "pass" && "${status}" -eq 0 ]] || [[ "${expect}" == "fail" && "${status}" -ne 0 ]]; then
    banner "CASE ${num}/${TOTAL_CASES}: ${label} — PASSED (${expect}ed as expected)"
    return 0
  else
    banner "CASE ${num}/${TOTAL_CASES}: ${label} — FAILED (expected to ${expect}, exit status was ${status})"
    return 1
  fi
}

FAILED=0
run_case 1 "license"    pass --license-key "${MATRIX_LICENSE_KEY}" || FAILED=1
run_case 2 "no-license" fail --license-key ""                      || FAILED=1
run_case 3 "bypass"     pass --license-key "" --license-bypass     || FAILED=1

if [[ "${FAILED}" -eq 0 ]]; then
  banner "[PASS] All license-key matrix cases behaved as expected"
else
  banner "[FAIL] One or more license-key matrix cases did not behave as expected"
fi
exit "${FAILED}"
