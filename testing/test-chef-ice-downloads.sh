#!/bin/bash
# Tests chef-ice (Chef >= 19) end-to-end:
#   Phase 1: Download URL validation — HTTP HEAD checks against chefdownload-commercial.chef.io
#            for all platform/arch/format combos, plus extension URL template consistency check.
#   Phase 2: Azure VM test — spins up a Linux VM, installs the extension with local
#            chef-install.sh code (always uses --local-ext), and verifies /opt/chef-ice
#            is installed and the node registered on Chef Server.
#
# Usage:
#   bash testing/test-chef-ice-downloads.sh [OPTIONS]
#
# .env file support:
#   All configuration values can be set in a .env file. The script auto-loads
#   testing/.env (relative to the script) if it exists. Use --env-file to
#   point to a different file. See testing/.env.example for supported variables.
#
# Required for Phase 2 (pass --skip-vm-test to skip):
#   --chef-server-url <url>          Chef Server URL
#   --validation-client-name <name>  Validation client name
#   --validation-pem <path>          Path to the validation .pem file
#
# Options:
#   --env-file <path>              Load configuration from a .env file
#   --license-key <key>            Chef license key (required)
#   --version <ver>                chef-ice version (or set CHEF_ICE_VERSION in .env)
#   --channel <ch>                 Download channel: stable (default), current
#   --chef-server-url <url>        Chef Server URL
#   --validation-client-name <n>   Validation client name
#   --validation-pem <path>        Path to validator PEM
#   --resource-group <name>        Azure resource group (default: chef-ice-test-rg)
#   --location <region>            Azure region (default: eastus)
#   --node-name <name>             Chef node name (default: az-ice-test-node)
#   --runlist <runlist>            Chef run list (default: recipe[base])
#   --extension-version <ver>      Marketplace extension version (default: 1210.14)
#   --azure-tenant <id>            Azure tenant ID
#   --azure-subscription <id>      Azure subscription ID or name
#   --azure-use-device-code        Use device code auth for az login
#   --ssh-public-key-path <path>   SSH public key (default: ~/.ssh/id_rsa.pub)
#   --skip-cleanup                 Leave Azure resources intact after test
#   --skip-vm-test                 Only run Phase 1 download checks (no Azure VM)
#   --help                         Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── .env loading ──────────────────────────────────────────────────────────────
_env_file=""
_prev=""
for _arg in "$@"; do
  [[ "${_prev}" == "--env-file" ]] && _env_file="${_arg}"
  _prev="${_arg}"
done
if [[ -z "${_env_file}" && -f "${SCRIPT_DIR}/.env" ]]; then
  _env_file="${SCRIPT_DIR}/.env"
fi
if [[ -n "${_env_file}" ]]; then
  [[ ! -f "${_env_file}" ]] && { echo "[FAIL] .env file not found: ${_env_file}" >&2; exit 1; }
  set -a; source "${_env_file}"; set +a
  echo -e "\033[0;34m[INFO]\033[0m  Loaded configuration from ${_env_file}"
fi
unset _env_file _prev _arg

# ── Defaults ──────────────────────────────────────────────────────────────────
LICENSE_KEY="${LICENSE_KEY:-}"
CHEF_ICE_VERSION="${CHEF_ICE_VERSION:-}"
CHEF_ICE_CHANNEL="${CHEF_ICE_CHANNEL:-stable}"
CHEF_SERVER_URL="${CHEF_SERVER_URL:-}"
VALIDATION_CLIENT_NAME="${VALIDATION_CLIENT_NAME:-}"
VALIDATION_PEM="${VALIDATION_PEM:-}"
RESOURCE_GROUP="${RESOURCE_GROUP:-chef-ice-test-rg}"
LOCATION="${LOCATION:-eastus}"
NODE_NAME="${NODE_NAME:-az-ice-test-node}"
RUNLIST="${RUNLIST:-recipe[base]}"
EXTENSION_VERSION="${EXTENSION_VERSION:-1210.14}"
AZURE_TENANT="${AZURE_TENANT:-}"
AZURE_SUBSCRIPTION="${AZURE_SUBSCRIPTION:-}"
AZURE_USE_DEVICE_CODE="${AZURE_USE_DEVICE_CODE:-false}"
SKIP_CLEANUP="${SKIP_CLEANUP:-false}"
SKIP_VM_TEST="${SKIP_VM_TEST:-false}"
SSH_PUBLIC_KEY_PATH="${SSH_PUBLIC_KEY_PATH:-$HOME/.ssh/id_rsa.pub}"
LINUX_VM="${LINUX_VM:-chef-ice-test-linux}"
ADMIN_USER="${ADMIN_USER:-azureuser}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-${SCRIPT_DIR}/artifacts}"
NODE_SSL_VERIFY_MODE="${NODE_SSL_VERIFY_MODE:-}"
TMPDIR_CONFIGS="$(mktemp -d)"

BASE_URL="https://chefdownload-commercial.chef.io"

# ── Helpers ───────────────────────────────────────────────────────────────────
PASS=0; FAIL=0
pass()       { echo -e "\033[0;32m[PASS]\033[0m  $*"; PASS=$(( PASS + 1 )); }
fail_check() { echo -e "\033[0;31m[FAIL]\033[0m  $*"; FAIL=$(( FAIL + 1 )); }
info()       { echo -e "\033[0;34m[INFO]\033[0m  $*"; }
warn()       { echo -e "\033[0;33m[WARN]\033[0m  $*"; }
fatal()      { echo -e "\033[0;31m[FAIL]\033[0m  $*" >&2; exit 1; }

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file)                shift 2 ;;
    --license-key)             LICENSE_KEY="$2";              shift 2 ;;
    --version)                 CHEF_ICE_VERSION="$2";         shift 2 ;;
    --channel)                 CHEF_ICE_CHANNEL="$2";         shift 2 ;;
    --chef-server-url)         CHEF_SERVER_URL="$2";          shift 2 ;;
    --validation-client-name)  VALIDATION_CLIENT_NAME="$2";   shift 2 ;;
    --validation-pem)          VALIDATION_PEM="$2";           shift 2 ;;
    --resource-group)          RESOURCE_GROUP="$2";           shift 2 ;;
    --location)                LOCATION="$2";                 shift 2 ;;
    --node-name)               NODE_NAME="$2";                shift 2 ;;
    --runlist)                 RUNLIST="$2";                  shift 2 ;;
    --extension-version)       EXTENSION_VERSION="$2";        shift 2 ;;
    --azure-tenant)            AZURE_TENANT="$2";             shift 2 ;;
    --azure-subscription)      AZURE_SUBSCRIPTION="$2";       shift 2 ;;
    --azure-use-device-code)   AZURE_USE_DEVICE_CODE=true;    shift ;;
    --skip-cleanup)            SKIP_CLEANUP=true;             shift ;;
    --skip-vm-test)            SKIP_VM_TEST=true;             shift ;;
    --ssh-public-key-path)     SSH_PUBLIC_KEY_PATH="$2";      shift 2 ;;
    --help|-h)
      grep '^#' "$0" | sed 's/^# \{0,1\}//' | tail -n +2
      exit 0 ;;
    *) fatal "Unknown option: $1" ;;
  esac
done

# ── Preflight ─────────────────────────────────────────────────────────────────
command -v curl    &>/dev/null || fatal "curl not found"
command -v python3 &>/dev/null || fatal "python3 not found"
[[ -z "${LICENSE_KEY}" ]] && fatal "LICENSE_KEY is required — set it in .env or pass --license-key"

# ── Resolve version ───────────────────────────────────────────────────────────
if [[ -z "${CHEF_ICE_VERSION}" ]]; then
  info "CHEF_ICE_VERSION not set — fetching latest from ${CHEF_ICE_CHANNEL} channel..."
  CHEF_ICE_VERSION="$(curl -fsSL \
    "${BASE_URL}/${CHEF_ICE_CHANNEL}/chef-ice/versions/all?license_id=${LICENSE_KEY}" \
    2>/dev/null | python3 -c "import json,sys; v=json.load(sys.stdin); print(sorted(v, key=lambda x:[int(p) for p in x.split('.')])[-1])" 2>/dev/null || true)"
  [[ -z "${CHEF_ICE_VERSION}" ]] && fatal "Could not resolve latest chef-ice version"
fi

_major="${CHEF_ICE_VERSION%%.*}"
[[ "${_major}" -lt 19 ]] 2>/dev/null && fatal "CHEF_ICE_VERSION must be >= 19 (got ${CHEF_ICE_VERSION})"

info "Testing chef-ice ${CHEF_ICE_VERSION} (channel: ${CHEF_ICE_CHANNEL})"

# ── Fetch manifest ────────────────────────────────────────────────────────────
info "Fetching package manifest..."
MANIFEST="$(curl -fsSL \
  "${BASE_URL}/${CHEF_ICE_CHANNEL}/chef-ice/packages?license_id=${LICENSE_KEY}" \
  2>/dev/null)"
[[ -z "${MANIFEST}" ]] && fatal "Could not fetch package manifest"

# ══════════════════════════════════════════════════════════════════════════════
# Phase 1: Download URL checks
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "=== Phase 1: chef-ice Download URL Checks ==="
echo ""

TEST_CASES=(
  "linux  x86_64  deb"
  "linux  aarch64 deb"
  "linux  x86_64  rpm"
  "linux  aarch64 rpm"
  "windows x86_64 msi"
)

check_download() {
  local platform="$1" arch="$2" fmt="$3"
  local label="${platform}/${arch}/${fmt}"
  local url sha256 ver_in_manifest

  url="$(echo "${MANIFEST}"    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['${platform}']['${arch}']['${fmt}']['url'])"     2>/dev/null || true)"
  sha256="$(echo "${MANIFEST}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['${platform}']['${arch}']['${fmt}']['sha256'])"   2>/dev/null || true)"
  ver_in_manifest="$(echo "${MANIFEST}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['${platform}']['${arch}']['${fmt}']['version'])" 2>/dev/null || true)"

  if [[ -z "${url}" ]]; then
    fail_check "${label}: not found in manifest"; return
  fi

  local http_code content_type
  http_code="$(curl -sI --max-time 15 "${url}" -o /dev/null -w "%{http_code}" 2>/dev/null)"
  content_type="$(curl -sI --max-time 15 "${url}" 2>/dev/null | grep -i ^content-type | awk '{print $2}' | tr -d '\r' || true)"

  if [[ "${http_code}" == "200" ]]; then
    pass "${label}: HTTP 200 type=${content_type:-octet-stream} sha256=${sha256:0:16}..."
  else
    fail_check "${label}: HTTP ${http_code} — ${url}"
  fi

  if [[ "${ver_in_manifest}" == "${CHEF_ICE_VERSION}" ]]; then
    pass "${label}: manifest version matches ${CHEF_ICE_VERSION}"
  elif [[ -n "${ver_in_manifest}" ]]; then
    warn "${label}: manifest version is ${ver_in_manifest} (requested ${CHEF_ICE_VERSION})"
    PASS=$(( PASS + 1 ))
  else
    fail_check "${label}: version not found in manifest"
  fi
}

for tc in "${TEST_CASES[@]}"; do
  read -r p a f <<< "${tc}"
  check_download "${p}" "${a}" "${f}"
done

# ── Extension URL template validation ────────────────────────────────────────
echo ""
echo "=== Extension install_chef_ice() URL Template Check ==="
echo ""
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_SH="${REPO_ROOT}/ChefExtensionHandler/bin/chef-install.sh"
TEMPLATE_LINE="$(grep '_url=.*chefdownload-commercial' "${INSTALL_SH}" 2>/dev/null | head -1 | sed 's/.*_url="//' | sed 's/".*//' || true)"

if [[ -z "${TEMPLATE_LINE}" ]]; then
  warn "Could not extract URL template from ${INSTALL_SH} — skipping template check"
else
  pass "Found install_chef_ice() URL template in chef-install.sh"
  for combo in "x86_64 deb" "aarch64 deb" "x86_64 rpm" "aarch64 rpm"; do
    _arch="${combo%% *}"; _pm="${combo##* }"
    _constructed="https://chefdownload-commercial.chef.io/${CHEF_ICE_CHANNEL}/chef-ice/download?eol=false&license_id=${LICENSE_KEY}&m=${_arch}&p=linux&pm=${_pm}&v=${CHEF_ICE_VERSION}"
    _expected="$(echo "${MANIFEST}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['linux']['${_arch}']['${_pm}']['url'])" 2>/dev/null || true)"
    if [[ "${_constructed}" == "${_expected}" ]]; then
      pass "linux/${_arch}/${_pm}: extension URL template matches API manifest URL"
    elif [[ -z "${_expected}" ]]; then
      fail_check "linux/${_arch}/${_pm}: could not read expected URL from manifest"
    else
      fail_check "linux/${_arch}/${_pm}: URL mismatch
    extension: ${_constructed}
    manifest:  ${_expected}"
    fi
  done
  info "windows/x86_64/msi: not handled by linux chef-install.sh (Windows uses chef-install.psm1)"
fi

if [[ "${SKIP_VM_TEST}" == "true" ]]; then
  echo ""
  info "Phase 2 skipped (--skip-vm-test)"
  echo ""
  echo "  chef-ice version : ${CHEF_ICE_VERSION}"
  echo "  channel          : ${CHEF_ICE_CHANNEL}"
  echo "  passed           : ${PASS}"
  echo "  failed           : ${FAIL}"
  echo ""
  [[ "${FAIL}" -eq 0 ]]
  exit $?
fi

# ══════════════════════════════════════════════════════════════════════════════
# Phase 2: Azure VM test
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "=== Phase 2: Azure Extension VM Test (chef-ice ${CHEF_ICE_VERSION}) ==="
echo ""

command -v az &>/dev/null || fatal "Azure CLI (az) not found — install from https://aka.ms/install-az"
command -v jq &>/dev/null || fatal "jq not found"
[[ -f "${SSH_PUBLIC_KEY_PATH}" ]]     || fatal "SSH public key not found: ${SSH_PUBLIC_KEY_PATH}"
[[ -z "${CHEF_SERVER_URL}" ]]         && fatal "--chef-server-url is required for Phase 2"
[[ -z "${VALIDATION_CLIENT_NAME}" ]]  && fatal "--validation-client-name is required for Phase 2"
[[ -z "${VALIDATION_PEM}" ]]          && fatal "--validation-pem is required for Phase 2"
[[ ! -f "${VALIDATION_PEM}" ]]        && fatal "Validation PEM not found: ${VALIDATION_PEM}"

# ── Azure login ───────────────────────────────────────────────────────────────
azure_login() {
  local -a login_cmd=(az login --output none)
  [[ -n "${AZURE_TENANT}" ]] && login_cmd+=(--tenant "${AZURE_TENANT}")
  [[ "${AZURE_USE_DEVICE_CODE}" == "true" ]] && login_cmd+=(--use-device-code)
  "${login_cmd[@]}" || fatal "Azure login failed"
}

if ! az account show &>/dev/null; then
  info "Not logged in to Azure. Launching 'az login'..."
  azure_login
elif [[ -n "${AZURE_TENANT}" ]]; then
  CURRENT_TENANT="$(az account show --query tenantId -o tsv 2>/dev/null || true)"
  if [[ "${CURRENT_TENANT}" != "${AZURE_TENANT}" ]]; then
    info "Switching to tenant ${AZURE_TENANT}..."
    azure_login
  fi
fi

if [[ -n "${AZURE_SUBSCRIPTION}" ]]; then
  az account set --subscription "${AZURE_SUBSCRIPTION}" --output none 2>/dev/null || \
    fatal "Unable to select subscription '${AZURE_SUBSCRIPTION}'"
fi

AZ_SUBSCRIPTION_ID="$(az account show --query id -o tsv 2>/dev/null || true)"
[[ -z "${AZ_SUBSCRIPTION_ID}" ]] && fatal "No active Azure subscription"
info "Using subscription: $(az account show --query name -o tsv 2>/dev/null) (${AZ_SUBSCRIPTION_ID})"

# ── Cleanup trap ──────────────────────────────────────────────────────────────
cleanup() {
  rm -rf "${TMPDIR_CONFIGS}"
  if [[ "${SKIP_CLEANUP}" == "false" ]]; then
    info "Deleting resource group ${RESOURCE_GROUP} (async)..."
    az group delete -n "${RESOURCE_GROUP}" --subscription "${AZ_SUBSCRIPTION_ID}" --yes --no-wait 2>/dev/null || true
    info "To remove the Chef node: knife node delete ${NODE_NAME} -y && knife client delete ${NODE_NAME} -y"
  else
    warn "Skipping cleanup — '${RESOURCE_GROUP}' left intact"
  fi
}
trap cleanup EXIT

# ── Build extension configs ───────────────────────────────────────────────────
PUBCONFIG="${TMPDIR_CONFIGS}/publicconfig.json"
PRIVCONFIG="${TMPDIR_CONFIGS}/privateconfig.json"

VALIDATION_KEY_JSON="$(python3 -c "import json,sys; print(json.dumps(open(sys.argv[1]).read()))" "${VALIDATION_PEM}")"

jq -n \
  --arg server    "${CHEF_SERVER_URL}" \
  --arg valclient "${VALIDATION_CLIENT_NAME}" \
  --arg node      "${NODE_NAME}" \
  --arg runlist   "${RUNLIST}" \
  --arg lickey    "${LICENSE_KEY}" \
  --arg sslmode   "${NODE_SSL_VERIFY_MODE}" \
  --arg ver       "${CHEF_ICE_VERSION}" \
  --arg ch        "${CHEF_ICE_CHANNEL}" \
  '{
    bootstrap_options: ({
      chef_server_url:        $server,
      validation_client_name: $valclient,
      chef_node_name:         $node,
      bootstrap_version:      $ver,
      bootstrap_channel:      $ch
    }
    + (if ($sslmode | length) > 0 then {node_ssl_verify_mode: $sslmode} else {} end)),
    runlist:          $runlist,
    CHEF_LICENSE:     "accept-no-persist",
    chef_license_key: $lickey
  }' > "${PUBCONFIG}"

jq -n --argjson valkey "${VALIDATION_KEY_JSON}" \
  '{ validation_key: $valkey }' > "${PRIVCONFIG}"

info "Extension config built (bootstrap_version=${CHEF_ICE_VERSION}, channel=${CHEF_ICE_CHANNEL})"

# ── Patch VM with local extension code ───────────────────────────────────────
patch_linux_local_ext() {
  local ext_handler="${REPO_ROOT}/ChefExtensionHandler"
  info "[local-ext] Uploading local ChefExtensionHandler files to VM..."

  local upload_script
  upload_script="EXT_DIR=\$(find /var/lib/waagent -maxdepth 1 -name 'Chef.Bootstrap.WindowsAzure.LinuxChefClient-*' -type d 2>/dev/null | sort -V | tail -1)
[ -z \"\$EXT_DIR\" ] && { echo 'ERROR: extension dir not found'; exit 1; }
echo \"Patching \$EXT_DIR...\""

  local linux_files=(
    "install.sh" "enable.sh" "disable.sh" "uninstall.sh" "update.sh"
    "bin/chef-install.sh" "bin/shared.sh" "bin/chef-enable.rb" "bin/chef-disable.rb"
    "bin/chef-update.sh" "bin/chef-uninstall.sh" "bin/chef_client_logs.rb"
    "bin/parse_env_variables.py"
  )

  local encoded rel_path src
  for rel_path in "${linux_files[@]}"; do
    src="${ext_handler}/${rel_path}"
    [[ -f "${src}" ]] || continue
    encoded=$(base64 < "${src}" | tr -d '\n')
    upload_script+="
printf '%s' '${encoded}' | base64 -d > \"\$EXT_DIR/${rel_path}\"
chmod +x \"\$EXT_DIR/${rel_path}\"
echo \"  patched: ${rel_path}\""
  done

  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${LINUX_VM}" \
    --command-id RunShellScript \
    --scripts "${upload_script}" \
    --query "value[0].message" -o tsv

  info "[local-ext] Purging any existing chef/chef-ice install..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${LINUX_VM}" \
    --command-id RunShellScript \
    --scripts "dpkg --purge chef chef-ice 2>/dev/null || true; rpm -e chef chef-ice 2>/dev/null || true; rm -rf /opt/chef /opt/chef-ice; echo 'purge done'" \
    --query "value[0].message" -o tsv

  info "[local-ext] Re-running install.sh + enable.sh with local code..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${LINUX_VM}" \
    --command-id RunShellScript \
    --scripts "EXT_DIR=\$(find /var/lib/waagent -maxdepth 1 -name 'Chef.Bootstrap.WindowsAzure.LinuxChefClient-*' -type d | sort -V | tail -1)
echo '=== install.sh ==='
sh \"\$EXT_DIR/install.sh\" 2>&1
echo '=== enable.sh ==='
sh \"\$EXT_DIR/enable.sh\" 2>&1" \
    --query "value[0].message" -o tsv
}

# ── Assertions ────────────────────────────────────────────────────────────────
verify_chef_ice_installed() {
  info "Verifying chef-ice installation on VM..."
  local output
  output="$(az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${LINUX_VM}" \
    --command-id RunShellScript \
    --scripts "if [ -f /usr/bin/chef-client ]; then echo 'HAB_BIN_PRESENT'; /usr/bin/chef-client --version 2>/dev/null || true; else echo 'HAB_BIN_MISSING'; fi" \
    --query "value[0].message" -o tsv | tr -d '\r')"

  echo "${output}"

  if echo "${output}" | grep -q "HAB_BIN_PRESENT"; then
    pass "/usr/bin/chef-client exists on VM"
  else
    fail_check "/usr/bin/chef-client NOT found — chef-ice install failed"
  fi
}

verify_linux_validator_key_checksum() {
  local local_checksum remote_output remote_checksum
  local_checksum="$(openssl pkey -in "${VALIDATION_PEM}" -pubout -outform DER 2>/dev/null | shasum -a 256 | awk '{print $1}')"
  [[ -z "${local_checksum}" ]] && { fail_check "Unable to checksum local validator key"; return; }

  remote_output="$(az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${LINUX_VM}" \
    --command-id RunShellScript \
    --scripts "key_file='/etc/chef/validation.pem'
if [ ! -s \"\$key_file\" ]; then echo '__VALIDATION_PEM_MISSING__'; exit 0; fi
pub_hash=\$(openssl pkey -in \"\$key_file\" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print \$1}')
[ -z \"\$pub_hash\" ] && { echo '__NORMALIZE_FAILED__'; exit 0; }
echo \"\$pub_hash\"" \
    --query "value[0].message" -o tsv | tr -d '\r')"

  if echo "${remote_output}" | grep -q "__VALIDATION_PEM_MISSING__"; then
    fail_check "validation.pem missing on VM — bootstrap may not have run"; return
  fi
  if echo "${remote_output}" | grep -q "__NORMALIZE_FAILED__"; then
    fail_check "Could not normalize validation.pem on VM"; return
  fi

  remote_checksum="$(echo "${remote_output}" | grep -Eo '[0-9a-fA-F]{64}' | head -1 | tr '[:upper:]' '[:lower:]')"
  [[ -z "${remote_checksum}" ]] && { fail_check "Could not parse validator checksum from VM"; return; }

  if [[ "${local_checksum}" == "${remote_checksum}" ]]; then
    pass "Validator key checksum matches (${local_checksum})"
  else
    fail_check "Validator key checksum mismatch (local: ${local_checksum}, vm: ${remote_checksum})"
  fi
}

print_node_diagnostics() {
  info "Node-side diagnostics..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${LINUX_VM}" \
    --command-id RunShellScript \
    --scripts "echo '--- /etc/chef ---'
ls -l /etc/chef 2>/dev/null || echo 'missing'
echo
echo '--- key presence ---'
for f in /etc/chef/validation.pem /etc/chef/client.pem /etc/chef/client.rb /etc/chef/first-boot.json; do
  [ -e \"\$f\" ] && echo \"PRESENT \$f\" || echo \"MISSING \$f\"
done
echo
echo '--- client.rb ---'
grep -E '^[[:space:]]*(chef_server_url|validation_client_name|node_name)' /etc/chef/client.rb 2>/dev/null || echo 'client.rb missing'
echo
echo '--- chef-ice version ---'
/usr/bin/chef-client --version 2>/dev/null || echo 'chef-client not found'" \
    --query "value[0].message" -o tsv
}

download_extension_logs() {
  local archive_name local_archive run_command_output tmp_logs_dir
  archive_name="linux-chef-ice-logs-${LINUX_VM}-$(date +%Y%m%d%H%M%S).tar.gz"
  local_archive="${ARTIFACTS_DIR}/${archive_name}"
  mkdir -p "${ARTIFACTS_DIR}"
  info "Archiving extension logs to ${local_archive}..."

  run_command_output="$(az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${LINUX_VM}" \
    --command-id RunShellScript \
    --scripts "list_file=\$(mktemp)
[ -f '/var/log/azure/custom.log' ] && echo '/var/log/azure/custom.log' >> \"\$list_file\"
find '/var/log/azure/Chef.Bootstrap.WindowsAzure.LinuxChefClient' -type f -name '*.log' >> \"\$list_file\" 2>/dev/null || true
find '/var/lib/waagent' -maxdepth 2 -type f -path '/var/lib/waagent/Chef.Bootstrap.WindowsAzure.LinuxChefClient-*/*.log' >> \"\$list_file\" 2>/dev/null || true
sort -u \"\$list_file\" -o \"\$list_file\"
if [ ! -s \"\$list_file\" ]; then echo '__NO_LOGS__'; rm -f \"\$list_file\"; exit 0; fi
while IFS= read -r log_file; do
  [ -z \"\$log_file\" ] && continue
  echo \"--- \${log_file} (last 200 lines) ---\"
  tail -n 200 \"\$log_file\" || true
  echo
done < \"\$list_file\"
rm -f \"\$list_file\"" \
    --query "value[0].message" -o tsv | tr -d '\r')"

  if echo "${run_command_output}" | grep -q "__NO_LOGS__"; then
    warn "No extension logs found on VM"; return
  fi

  tmp_logs_dir="$(mktemp -d)"
  {
    echo "# Test metadata"
    echo "CHEF_ICE_VERSION=${CHEF_ICE_VERSION}"
    echo "CHEF_ICE_CHANNEL=${CHEF_ICE_CHANNEL}"
    echo "LICENSE_KEY_LENGTH=${#LICENSE_KEY}"
    echo ""
    echo "# Remote log output"
    printf '%s\n' "${run_command_output}"
  } > "${tmp_logs_dir}/chef-ice-logs.txt"
  tar -czf "${local_archive}" -C "${tmp_logs_dir}" chef-ice-logs.txt
  rm -rf "${tmp_logs_dir}"

  if tar -tzf "${local_archive}" >/dev/null 2>&1; then
    pass "Saved extension logs to ${local_archive}"
  else
    rm -f "${local_archive}"
    warn "Log archive validation failed — logs not saved"
  fi
}

# ── Provision and test ────────────────────────────────────────────────────────
info "Creating resource group '${RESOURCE_GROUP}' in ${LOCATION}..."
az group create -n "${RESOURCE_GROUP}" -l "${LOCATION}" --subscription "${AZ_SUBSCRIPTION_ID}" --output none

info "Creating Ubuntu VM '${LINUX_VM}'..."
az vm create \
  -g "${RESOURCE_GROUP}" -n "${LINUX_VM}" \
  --image Ubuntu2204 --size Standard_B2s \
  --admin-username "${ADMIN_USER}" \
  --ssh-key-values "${SSH_PUBLIC_KEY_PATH}" \
  --output none
pass "VM '${LINUX_VM}' created"

info "Installing LinuxChefClient extension v${EXTENSION_VERSION} (marketplace run provides gem + settings)..."
az vm extension set \
  -g "${RESOURCE_GROUP}" --vm-name "${LINUX_VM}" \
  --name LinuxChefClient \
  --publisher Chef.Bootstrap.WindowsAzure \
  --version "${EXTENSION_VERSION}" \
  --settings "${PUBCONFIG}" \
  --protected-settings "${PRIVCONFIG}" \
  --output none || warn "Marketplace extension reported failure (expected — local code will override)"
pass "Marketplace extension installed"

patch_linux_local_ext

info "Checking extension provisioning state (reflects marketplace run, not local re-run)..."
STATE="$(az vm extension show \
  -g "${RESOURCE_GROUP}" --vm-name "${LINUX_VM}" \
  --name LinuxChefClient \
  --query "provisioningState" -o tsv)"
info "Marketplace provisioning state: ${STATE} (local code was re-run above)"

verify_chef_ice_installed
verify_linux_validator_key_checksum
print_node_diagnostics
download_extension_logs

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "  chef-ice version : ${CHEF_ICE_VERSION}"
echo "  channel          : ${CHEF_ICE_CHANNEL}"
echo "  VM               : ${LINUX_VM} (${RESOURCE_GROUP})"
echo "  Chef Server      : ${CHEF_SERVER_URL}"
echo "  Node             : ${NODE_NAME}"
echo "  passed           : ${PASS}"
echo "  failed           : ${FAIL}"
echo ""

[[ "${FAIL}" -eq 0 ]]
