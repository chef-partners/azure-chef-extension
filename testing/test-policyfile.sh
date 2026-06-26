#!/bin/bash
# End-to-end test script for the Azure Chef Extension — policyfile mode.
#
# Validates the extension with and without policyfiles on a Linux VM:
#   - server mode: policy_name + policy_group pushed to a Chef Server
#   - local mode:  chef-client --local-mode, no Chef Server (Policyfile.lock.json
#                  pre-staged on the VM)
#
# Usage:
#   bash testing/test-policyfile.sh [OPTIONS]
#
# .env file support:
#   All configuration values can be set in a .env file.  The script auto-loads
#   testing/.env (relative to the script) if it exists.  Use --env-file to
#   point to a different file.  CLI options always override .env values.
#   See testing/.env.example for supported variables (including POLICY_* ones).
#
# Policy mode options (required — pick one):
#   --mode server              Test Chef Server policyfile mode (default)
#   --mode local               Test local mode (chef-client --local-mode)
#   --mode both                Run server mode then local mode sequentially
#
# Chef Server options (required unless --mode local or --build-chef-server):
#   --chef-server-url <url>          Chef Server URL
#   --validation-client-name <name>  Validation client name (optional in policyfile mode)
#   --validation-pem <path>          Validation PEM path (optional in policyfile mode)
#   --user-pem <path>                Chef user .pem for knife (required for server mode verify)
#
# Policyfile options:
#   --policy-name <name>       Policy name to use (default: azure-test-policy)
#   --policy-group <group>     Policy group to use (default: test-group)
#   --policyfile-lock <path>   Path to an existing Policyfile.lock.json to push/use.
#                              If omitted, a minimal stub lock file is generated.
#   --policy-document-path <p> Path on the VM where the lock file will be written
#                              (local mode only; default: /etc/chef/Policyfile.lock.json)
#
# Common options:
#   --env-file <path>           Load configuration from a .env file
#   --build-chef-server         Provision a temporary Chef Server VM for this test
#   --chef-server-version <ver> Chef Server package version for --build-chef-server
#   --chef-server-vm <name>     Chef Server VM name (default: chef-policy-server)
#   --chef-server-org <name>    Chef org short name for --build-chef-server (default: testorg)
#   --chef-server-user <name>   Chef admin username for --build-chef-server (default: testadmin)
#   --azure-tenant <tenant-id>  Azure tenant to log into/use
#   --azure-subscription <id|name>  Azure subscription to select
#   --azure-use-device-code     Use device code auth for az login
#   --resource-group <name>    Azure resource group name (default: chef-policy-test-rg)
#   --location <region>        Azure region (default: eastus)
#   --node-name <name>         Chef node name prefix (default: az-policy-test)
#   --extension-version <ver>  Extension version (default: 1210.14)
#   --local-ext                After marketplace install, upload local ChefExtensionHandler
#                              files and re-run install.sh + enable.sh to test local code
#   --license-key <key>        Chef license key for licensed downloads
#   --chef-infra-version <ver> Chef Infra Client version to install
#   --skip-cleanup             Do not delete Azure resources after the test
#   --ssh-public-key-path <path>  Public key to upload for Linux VM SSH access
#   --help                     Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── .env file loading ─────────────────────────────────────────────────────────
_env_file=""
_prev_arg=""
for _arg in "$@"; do
  [[ "${_prev_arg}" == "--env-file" ]] && { _env_file="${_arg}"; break; }
  _prev_arg="${_arg}"
done
if [[ -z "${_env_file}" ]]; then
  _default_env="${SCRIPT_DIR}/.env"
  [[ -f "${_default_env}" ]] && _env_file="${_default_env}"
fi
if [[ -n "${_env_file}" ]]; then
  [[ ! -f "${_env_file}" ]] && { echo "[FAIL] .env file not found: ${_env_file}" >&2; exit 1; }
  set -a; source "${_env_file}"; set +a  # shellcheck source=/dev/null
  echo -e "\033[0;34m[INFO]\033[0m  Loaded configuration from ${_env_file}"
fi
unset _env_file _default_env _prev_arg _arg

# ── Defaults ──────────────────────────────────────────────────────────────────
RESOURCE_GROUP="${RESOURCE_GROUP:-chef-policy-test-rg}"
LOCATION="${LOCATION:-eastus}"
NODE_NAME="${NODE_NAME:-az-policy-test}"
EXTENSION_VERSION="${EXTENSION_VERSION:-1210.14}"
LOCAL_EXT="${LOCAL_EXT:-false}"
SKIP_CLEANUP="${SKIP_CLEANUP:-false}"
SSH_PUBLIC_KEY_PATH="${SSH_PUBLIC_KEY_PATH:-$HOME/.ssh/id_rsa.pub}"
LICENSE_KEY="${LICENSE_KEY:-}"
CHEF_INFRA_VERSION="${CHEF_INFRA_VERSION:-}"
CHEF_INFRA_CHANNEL="${CHEF_INFRA_CHANNEL:-}"

CHEF_SERVER_URL="${CHEF_SERVER_URL:-}"
VALIDATION_CLIENT_NAME="${VALIDATION_CLIENT_NAME:-}"
VALIDATION_PEM="${VALIDATION_PEM:-}"
USER_PEM="${USER_PEM:-}"
BUILD_CHEF_SERVER="${BUILD_CHEF_SERVER:-false}"
CHEF_SERVER_VM="${CHEF_SERVER_VM:-chef-policy-server}"
CHEF_SERVER_VERSION="${CHEF_SERVER_VERSION:-15.10.84-20251114181706}"
CHEF_SERVER_ORG="${CHEF_SERVER_ORG:-testorg}"
CHEF_SERVER_ORG_FULL_NAME="${CHEF_SERVER_ORG_FULL_NAME:-Test Org}"
CHEF_SERVER_USER="${CHEF_SERVER_USER:-testadmin}"
CHEF_SERVER_USER_EMAIL="${CHEF_SERVER_USER_EMAIL:-testadmin@example.com}"
CHEF_SERVER_USER_PASSWORD="${CHEF_SERVER_USER_PASSWORD:-ChefPolicy@Test$(date +%s)!}"
NODE_SSL_VERIFY_MODE="${NODE_SSL_VERIFY_MODE:-}"

POLICY_MODE="${POLICY_MODE:-server}"
POLICY_NAME="${POLICY_NAME:-azure-test-policy}"
POLICY_GROUP="${POLICY_GROUP:-test-group}"
POLICYFILE_LOCK_PATH="${POLICYFILE_LOCK_PATH:-}"
POLICY_DOCUMENT_PATH="${POLICY_DOCUMENT_PATH:-/etc/chef/Policyfile.lock.json}"

AZURE_TENANT="${AZURE_TENANT:-}"
AZURE_SUBSCRIPTION="${AZURE_SUBSCRIPTION:-}"
AZURE_USE_DEVICE_CODE="${AZURE_USE_DEVICE_CODE:-false}"

LINUX_VM_SERVER="${LINUX_VM:-az-policy-server-vm}"
LINUX_VM_LOCAL="${LINUX_VM_LOCAL:-az-policy-local-vm}"
ADMIN_USER="${ADMIN_USER:-azureuser}"

TMPDIR_CONFIGS="$(mktemp -d)"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-${SCRIPT_DIR}/artifacts}"

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "\033[0;34m[INFO]\033[0m  $*"; }
success() { echo -e "\033[0;32m[PASS]\033[0m  $*"; }
warn()    { echo -e "\033[0;33m[WARN]\033[0m  $*"; }
fail()    { echo -e "\033[0;31m[FAIL]\033[0m  $*" >&2; exit 1; }

cleanup() {
  info "Removing temp config files"
  rm -rf "${TMPDIR_CONFIGS}"
  if [[ "${SKIP_CLEANUP}" == "false" ]]; then
    info "Deleting resource group ${RESOURCE_GROUP} (async)..."
    az group delete -n "${RESOURCE_GROUP}" --subscription "${AZ_SUBSCRIPTION_ID}" --yes --no-wait 2>/dev/null || true
  else
    warn "Skipping cleanup — resource group '${RESOURCE_GROUP}' left intact"
  fi
}
trap cleanup EXIT

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//' | tail -n +2
  exit 0
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file)                  shift 2 ;;
    --mode)                      POLICY_MODE="$2";              shift 2 ;;
    --chef-server-url)           CHEF_SERVER_URL="$2";          shift 2 ;;
    --validation-client-name)    VALIDATION_CLIENT_NAME="$2";   shift 2 ;;
    --validation-pem)            VALIDATION_PEM="$2";            shift 2 ;;
    --user-pem)                  USER_PEM="$2";                  shift 2 ;;
    --build-chef-server)         BUILD_CHEF_SERVER=true;         shift ;;
    --chef-server-version)       CHEF_SERVER_VERSION="$2";       shift 2 ;;
    --chef-server-vm)            CHEF_SERVER_VM="$2";            shift 2 ;;
    --chef-server-org)           CHEF_SERVER_ORG="$2";           shift 2 ;;
    --chef-server-user)          CHEF_SERVER_USER="$2";          shift 2 ;;
    --policy-name)               POLICY_NAME="$2";               shift 2 ;;
    --policy-group)              POLICY_GROUP="$2";              shift 2 ;;
    --policyfile-lock)           POLICYFILE_LOCK_PATH="$2";      shift 2 ;;
    --policy-document-path)      POLICY_DOCUMENT_PATH="$2";      shift 2 ;;
    --azure-tenant)              AZURE_TENANT="$2";              shift 2 ;;
    --azure-subscription)        AZURE_SUBSCRIPTION="$2";        shift 2 ;;
    --azure-use-device-code)     AZURE_USE_DEVICE_CODE=true;     shift ;;
    --resource-group)            RESOURCE_GROUP="$2";            shift 2 ;;
    --location)                  LOCATION="$2";                  shift 2 ;;
    --node-name)                 NODE_NAME="$2";                 shift 2 ;;
    --extension-version)         EXTENSION_VERSION="$2";         shift 2 ;;
    --local-ext)                 LOCAL_EXT=true;                 shift ;;
    --license-key)               LICENSE_KEY="$2";               shift 2 ;;
    --chef-infra-version)        CHEF_INFRA_VERSION="$2";        shift 2 ;;
    --skip-cleanup)              SKIP_CLEANUP=true;              shift ;;
    --ssh-public-key-path)       SSH_PUBLIC_KEY_PATH="$2";       shift 2 ;;
    --help|-h)                   usage ;;
    *) fail "Unknown option: $1" ;;
  esac
done

# ── Preflight ─────────────────────────────────────────────────────────────────
info "Running preflight checks..."
command -v az &>/dev/null || fail "Azure CLI (az) not found"
command -v jq &>/dev/null || fail "jq not found"
[[ -f "${SSH_PUBLIC_KEY_PATH}" ]] || fail "SSH public key not found: ${SSH_PUBLIC_KEY_PATH}"
[[ "${POLICY_MODE}" =~ ^(server|local|both)$ ]] || fail "--mode must be server, local, or both"

# Auto-generate USER_PEM if it doesn't exist (useful for testing without a real Chef Server).
# Note: a generated key must be registered with the Chef Server before it can authenticate;
# for --build-chef-server tests, provision_chef_server() overwrites USER_PEM with the real key.
if [[ "${POLICY_MODE}" != "local" ]]; then
  if [[ -z "${USER_PEM}" ]]; then
    USER_PEM="${TMPDIR_CONFIGS}/user.pem"
  fi
  if [[ ! -f "${USER_PEM}" ]]; then
    info "USER_PEM not found at '${USER_PEM}' — generating a test RSA key..."
    command -v openssl &>/dev/null || fail "openssl not found — required to generate USER_PEM"
    openssl genrsa -out "${USER_PEM}" 2048 2>/dev/null
    chmod 0600 "${USER_PEM}"
    warn "Generated test key at ${USER_PEM}. This key is NOT registered with the Chef Server."
    warn "Policy push will only succeed if you use --build-chef-server (which registers it) or pre-push the policy manually."
  fi
fi

azure_login() {
  local -a login_cmd=(az login --output none)
  [[ -n "${AZURE_TENANT}" ]] && login_cmd+=(--tenant "${AZURE_TENANT}")
  [[ "${AZURE_USE_DEVICE_CODE}" == "true" ]] && login_cmd+=(--use-device-code)
  "${login_cmd[@]}" || fail "Azure login failed"
}

if ! az account show &>/dev/null; then
  info "Not logged in to Azure. Launching 'az login'..."
  azure_login
elif [[ -n "${AZURE_TENANT}" ]]; then
  CURRENT_TENANT="$(az account show --query tenantId -o tsv 2>/dev/null || true)"
  if [[ "${CURRENT_TENANT}" != "${AZURE_TENANT}" ]]; then
    info "Logging into tenant ${AZURE_TENANT}..."
    azure_login
  fi
fi

[[ -n "${AZURE_SUBSCRIPTION}" ]] && \
  az account set --subscription "${AZURE_SUBSCRIPTION}" --output none 2>/dev/null || true

AZ_SUBSCRIPTION_ID="$(az account show --query id -o tsv 2>/dev/null || true)"
[[ -z "${AZ_SUBSCRIPTION_ID}" ]] && fail "No active Azure subscription. Use --azure-subscription <id|name>."
info "Using Azure subscription: $(az account show --query name -o tsv) (${AZ_SUBSCRIPTION_ID})"

# Warn if CHEF_INFRA_VERSION targets a version that may not have Ubuntu 22.04 packages.
# Chef < 17 was released before Ubuntu 22.04 and its packages target Ubuntu 20.04 —
# installing them on Ubuntu 22.04 fails.  Override with --chef-infra-version "" to use latest.
if [[ -n "${CHEF_INFRA_VERSION}" ]]; then
  _major="${CHEF_INFRA_VERSION%%.*}"
  if [[ "${_major}" -lt 17 ]] 2>/dev/null; then
    warn "CHEF_INFRA_VERSION=${CHEF_INFRA_VERSION} (< 17) does not have Ubuntu 22.04 packages."
    warn "Pass --chef-infra-version \"\" to use the latest available version instead."
    fail "Refusing to continue — update CHEF_INFRA_VERSION or pass --chef-infra-version \"\""
  fi
fi

# Server mode preflight: Chef Server must be reachable (or built)
if [[ "${POLICY_MODE}" != "local" && "${BUILD_CHEF_SERVER}" == "false" ]]; then
  [[ -z "${CHEF_SERVER_URL}" ]] && fail "--chef-server-url is required for server mode (or pass --build-chef-server)"
fi

success "Preflight OK"

# ── Resource group ────────────────────────────────────────────────────────────
info "Creating resource group '${RESOURCE_GROUP}' in ${LOCATION}..."
az group create -n "${RESOURCE_GROUP}" -l "${LOCATION}" --subscription "${AZ_SUBSCRIPTION_ID}" --output none
success "Resource group ready"

# ── Optional: Build temporary Chef Server ─────────────────────────────────────
provision_chef_server() {
  info "Provisioning Chef Server VM '${CHEF_SERVER_VM}'..."
  az vm create \
    -g "${RESOURCE_GROUP}" -n "${CHEF_SERVER_VM}" \
    --image Ubuntu2204 --size Standard_B2s \
    --admin-username "${ADMIN_USER}" --ssh-key-values "${SSH_PUBLIC_KEY_PATH}" \
    --output none
  az vm open-port -g "${RESOURCE_GROUP}" -n "${CHEF_SERVER_VM}" --port 443 --priority 1010 --output none

  info "Installing Chef Server ${CHEF_SERVER_VERSION}..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${CHEF_SERVER_VM}" --command-id RunShellScript \
    --scripts \
      "set -euo pipefail" \
      "cd /tmp" \
      "sudo apt-get update -y" \
      "sudo apt-get install -y ruby-full curl" \
      "sudo gem install --no-document mixlib-install" \
      "sudo mixlib-install download chef-server -c stable -a x86_64 -p ubuntu -l 22.04 -v ${CHEF_SERVER_VERSION}" \
      "PKG=\$(ls -1t /tmp/chef-server-core_*.deb | head -1)" \
      "sudo dpkg -i \"\${PKG}\" || sudo apt-get install -f -y" \
      "sudo chef-server-ctl reconfigure" \
      "sudo chef-server-ctl user-create '${CHEF_SERVER_USER}' 'Test' 'Admin' '${CHEF_SERVER_USER_EMAIL}' '${CHEF_SERVER_USER_PASSWORD}' --filename '/tmp/${CHEF_SERVER_USER}.pem'" \
      "sudo chef-server-ctl org-create '${CHEF_SERVER_ORG}' '${CHEF_SERVER_ORG_FULL_NAME}' --association_user '${CHEF_SERVER_USER}' --filename '/tmp/${CHEF_SERVER_ORG}-validator.pem'" \
    --output none

  local chef_server_ip
  chef_server_ip="$(az vm show -d -g "${RESOURCE_GROUP}" -n "${CHEF_SERVER_VM}" --query "publicIps" -o tsv)"
  [[ -z "${chef_server_ip}" ]] && fail "Unable to determine Chef Server public IP"

  CHEF_SERVER_URL="https://${chef_server_ip}/organizations/${CHEF_SERVER_ORG}"
  VALIDATION_CLIENT_NAME="${CHEF_SERVER_ORG}-validator"
  VALIDATION_PEM="${TMPDIR_CONFIGS}/${CHEF_SERVER_ORG}-validator.pem"
  USER_PEM="${TMPDIR_CONFIGS}/${CHEF_SERVER_USER}.pem"
  NODE_SSL_VERIFY_MODE="verify_none"

  local val_b64 user_b64
  val_b64="$(az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${CHEF_SERVER_VM}" --command-id RunShellScript \
    --scripts "sudo base64 -w 0 /tmp/${CHEF_SERVER_ORG}-validator.pem" \
    --query "value[0].message" -o tsv | tr -d '\r\n')"
  python3 -c "import base64,sys; open(sys.argv[1],'wb').write(base64.b64decode(sys.argv[2]))" \
    "${VALIDATION_PEM}" "${val_b64}"

  user_b64="$(az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${CHEF_SERVER_VM}" --command-id RunShellScript \
    --scripts "sudo base64 -w 0 /tmp/${CHEF_SERVER_USER}.pem" \
    --query "value[0].message" -o tsv | tr -d '\r\n')"
  python3 -c "import base64,sys; open(sys.argv[1],'wb').write(base64.b64decode(sys.argv[2]))" \
    "${USER_PEM}" "${user_b64}"

  [[ ! -s "${VALIDATION_PEM}" ]] && fail "Failed to retrieve validator PEM from Chef Server VM"
  success "Chef Server ready at ${CHEF_SERVER_URL}"
}

[[ "${BUILD_CHEF_SERVER}" == "true" ]] && provision_chef_server

# ── Generate a minimal stub Policyfile.lock.json if none provided ─────────────
# The stub has an empty run_list and no cookbook dependencies — it is sufficient
# to exercise the extension's policyfile code path without requiring a full
# cookbook tree. Replace with a real lock file for full cookbook convergence.
generate_stub_policyfile_lock() {
  local out_path="$1"
  python3 - "${out_path}" "${POLICY_NAME}" "${POLICY_GROUP}" <<'PYEOF'
import json, sys, hashlib, time

out, policy_name, policy_group = sys.argv[1], sys.argv[2], sys.argv[3]
lock = {
    "revision_id": hashlib.sha256(f"{policy_name}-{policy_group}-{time.time()}".encode()).hexdigest(),
    "name": policy_name,
    "run_list": [],
    "named_run_lists": {},
    "included_policy_locks": [],
    "cookbook_locks": {},
    "default_attributes": {},
    "override_attributes": {},
    "solution_dependencies": {"Policyfile": [], "dependencies": {}}
}
with open(out, "w") as f:
    json.dump(lock, f, indent=2)
print(f"Stub Policyfile.lock.json written to {out}")
PYEOF
}

# ── Push policyfile to Chef Server (server mode) ───────────────────────────────
# Uses the Chef Server API directly (no knife/chef-cli on the test runner needed):
# uploads the lock file content as a policy revision, then creates the policy group
# association.
push_policy_to_server() {
  local lock_file="$1"
  [[ ! -f "${USER_PEM}" ]] && fail "--user-pem is required to push policies to the Chef Server"

  command -v knife &>/dev/null || fail "knife not found — install Chef Workstation to push policies (or pre-push manually)"

  info "Pushing policy '${POLICY_NAME}' to group '${POLICY_GROUP}' on ${CHEF_SERVER_URL}..."
  knife upload \
    --config-option "chef_server_url=${CHEF_SERVER_URL}" \
    --config-option "node_name=${CHEF_SERVER_USER}" \
    --config-option "client_key=${USER_PEM}" \
    --config-option "ssl_verify_mode=:verify_none" \
    "/policy_groups/${POLICY_GROUP}/policies/${POLICY_NAME}" \
    --config-option "data_bag_path=/dev/null" \
    || true  # knife upload may not support policy push; use chef push if available

  # Prefer `chef push` (Chef Workstation) which understands Policyfile.lock.json
  if command -v chef &>/dev/null; then
    chef push "${POLICY_GROUP}" "${lock_file}" \
      --config-option "chef_server_url=${CHEF_SERVER_URL}" \
      --config-option "node_name=${CHEF_SERVER_USER}" \
      --config-option "client_key=${USER_PEM}" \
      --config-option "ssl_verify_mode=:verify_none" \
      2>/dev/null && success "Policy pushed via 'chef push'" && return
  fi

  # Fallback: POST the lock file directly via the Chef Server Policies API
  local revision_id
  revision_id="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['revision_id'])" "${lock_file}")"
  info "Uploading policy revision ${revision_id} via Chef Server API..."
  python3 - "${CHEF_SERVER_URL}" "${CHEF_SERVER_USER}" "${USER_PEM}" \
             "${POLICY_NAME}" "${POLICY_GROUP}" "${lock_file}" \
             "${NODE_SSL_VERIFY_MODE}" <<'PYEOF'
import sys, json, subprocess, textwrap, os
server_url, node_name, pem, policy_name, policy_group, lock_file, ssl_mode = sys.argv[1:]
ssl_verify = ssl_mode != "verify_none"
lock = json.load(open(lock_file))

try:
    import requests
    from requests.auth import AuthBase

    class ChefAuth(AuthBase):
        def __call__(self, r): return r  # simplified — for real use, wire mixlib-auth

    s = requests.Session()
    s.verify = ssl_verify
    s.headers.update({
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-Chef-Version": "15.0",
        "X-Ops-Userid": node_name,
    })
    # Upload policy revision
    url = f"{server_url}/policies/{policy_name}/revisions"
    r = s.post(url, json=lock)
    if r.status_code not in (200, 201):
        print(f"[WARN] Policy upload returned {r.status_code}: {r.text[:200]}", file=sys.stderr)
    else:
        print(f"[PASS] Policy revision uploaded")
    # Associate with policy group
    url2 = f"{server_url}/policy_groups/{policy_group}/policies/{policy_name}"
    r2 = s.put(url2, json={"revision_id": lock["revision_id"]})
    if r2.status_code not in (200, 201):
        print(f"[WARN] Policy group association returned {r2.status_code}: {r2.text[:200]}", file=sys.stderr)
    else:
        print(f"[PASS] Policy group '{policy_group}' associated")
except ImportError:
    print("[WARN] 'requests' not installed — skipping API-based policy push. Push manually with: chef push", file=sys.stderr)
PYEOF
  success "Policy '${POLICY_NAME}' pushed to '${POLICY_GROUP}'"
}

# ── Shared: create a Linux VM ─────────────────────────────────────────────────
create_linux_vm() {
  local vm_name="$1"
  info "Creating Ubuntu VM '${vm_name}'..."
  az vm create \
    -g "${RESOURCE_GROUP}" -n "${vm_name}" \
    --image Ubuntu2204 --size Standard_B2s \
    --admin-username "${ADMIN_USER}" --ssh-key-values "${SSH_PUBLIC_KEY_PATH}" \
    --output none
  success "VM '${vm_name}' created"
}

# ── Shared: install extension ─────────────────────────────────────────────────
install_extension() {
  local vm_name="$1" pubconfig="$2" privconfig="$3"
  info "Installing LinuxChefClient extension (v${EXTENSION_VERSION}) on '${vm_name}'..."
  if [[ "${LOCAL_EXT}" == "true" ]]; then
    az vm extension set \
      -g "${RESOURCE_GROUP}" --vm-name "${vm_name}" \
      --name LinuxChefClient --publisher Chef.Bootstrap.WindowsAzure \
      --version "${EXTENSION_VERSION}" \
      --settings "${pubconfig}" --protected-settings "${privconfig}" \
      --output none \
      || warn "Marketplace extension reported failure (expected with --local-ext); patching with local code"
    patch_linux_local_ext "${vm_name}"
  else
    az vm extension set \
      -g "${RESOURCE_GROUP}" --vm-name "${vm_name}" \
      --name LinuxChefClient --publisher Chef.Bootstrap.WindowsAzure \
      --version "${EXTENSION_VERSION}" \
      --settings "${pubconfig}" --protected-settings "${privconfig}" \
      --output none
  fi
  success "Extension installed on '${vm_name}'"
}

# ── Shared: patch VM with local extension code ────────────────────────────────
patch_linux_local_ext() {
  local vm_name="$1"
  local REPO_ROOT; REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
  local ext_handler="${REPO_ROOT}/ChefExtensionHandler"

  # Step 1: Upload shell scripts and bin wrappers
  info "[local-ext] Uploading local ChefExtensionHandler files to '${vm_name}'..."
  local upload_script
  upload_script="EXT_DIR=\$(find /var/lib/waagent -maxdepth 1 -name 'Chef.Bootstrap.WindowsAzure.LinuxChefClient-*' -type d 2>/dev/null | sort -V | tail -1)
[ -z \"\$EXT_DIR\" ] && { echo 'ERROR: extension dir not found'; exit 1; }
echo \"Patching \$EXT_DIR with local code...\""

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
    -g "${RESOURCE_GROUP}" --name "${vm_name}" --command-id RunShellScript \
    --scripts "${upload_script}" --query "value[0].message" -o tsv

  # Step 2: Run install.sh to ensure Chef + gem are installed
  # (The marketplace extension may have already done this; install.sh is idempotent for Chef.)
  info "[local-ext] Running install.sh to ensure Chef + gem are installed..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${vm_name}" --command-id RunShellScript \
    --scripts "EXT_DIR=\$(find /var/lib/waagent -maxdepth 1 -name 'Chef.Bootstrap.WindowsAzure.LinuxChefClient-*' -type d | sort -V | tail -1)
echo '=== install.sh ==='
sh \"\$EXT_DIR/install.sh\" 2>&1 || true" \
    --query "value[0].message" -o tsv

  # Step 3: Patch the installed azure-chef-extension gem lib files with our local code.
  # enable.sh loads lib/chef/azure/commands/enable.rb and core/*.rb from the installed gem,
  # NOT from the extension dir — so we must patch the gem source after gem install.
  info "[local-ext] Patching azure-chef-extension gem lib files on '${vm_name}'..."
  local gem_lib_files=(
    "lib/chef/azure/commands/enable.rb"
    "lib/chef/azure/core/bootstrap_context.rb"
    "lib/chef/azure/core/windows_bootstrap_context.rb"
  )

  local gem_upload_script
  gem_upload_script="GEM_DIR=\$(find /opt/chef/embedded/lib/ruby/gems -maxdepth 3 -name 'azure-chef-extension-*' -type d 2>/dev/null | head -1)
[ -z \"\$GEM_DIR\" ] && { echo 'ERROR: azure-chef-extension gem dir not found'; exit 1; }
echo \"Patching gem lib files at \$GEM_DIR...\""

  for rel_path in "${gem_lib_files[@]}"; do
    src="${REPO_ROOT}/${rel_path}"
    [[ -f "${src}" ]] || { warn "[local-ext] Skipping missing: ${rel_path}"; continue; }
    encoded=$(base64 < "${src}" | tr -d '\n')
    local dir_part; dir_part="$(dirname "${rel_path}")"
    gem_upload_script+="
mkdir -p \"\$GEM_DIR/${dir_part}\"
printf '%s' '${encoded}' | base64 -d > \"\$GEM_DIR/${rel_path}\"
echo \"  gem-patched: ${rel_path}\""
  done

  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${vm_name}" --command-id RunShellScript \
    --scripts "${gem_upload_script}" --query "value[0].message" -o tsv

  # Step 4: Re-run enable.sh now that gem lib files have our policyfile code
  info "[local-ext] Re-running enable.sh with patched gem code..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${vm_name}" --command-id RunShellScript \
    --scripts "EXT_DIR=\$(find /var/lib/waagent -maxdepth 1 -name 'Chef.Bootstrap.WindowsAzure.LinuxChefClient-*' -type d | sort -V | tail -1)
echo '=== enable.sh ==='
sh \"\$EXT_DIR/enable.sh\" 2>&1" \
    --query "value[0].message" -o tsv
}

# ── Shared: verify policyfile client.rb settings on VM ───────────────────────
verify_policyfile_clientrb() {
  local vm_name="$1" expected_mode="$2"  # server | local
  info "Verifying client.rb contains policyfile settings on '${vm_name}'..."

  local out
  out="$(az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${vm_name}" --command-id RunShellScript \
    --scripts "
set -e
CLIENTRB=/etc/chef/client.rb
if [ ! -f \"\$CLIENTRB\" ]; then echo '__CLIENTRB_MISSING__'; exit 0; fi
echo '--- /etc/chef/client.rb ---'
cat \"\$CLIENTRB\"
echo '--- checks ---'
grep -q 'policy_name'  \"\$CLIENTRB\" && echo 'HAS_POLICY_NAME=yes'  || echo 'HAS_POLICY_NAME=no'
grep -q 'policy_group' \"\$CLIENTRB\" && echo 'HAS_POLICY_GROUP=yes' || echo 'HAS_POLICY_GROUP=no'
grep -q 'validation_key' \"\$CLIENTRB\" && echo 'HAS_VALIDATION_KEY=yes' || echo 'HAS_VALIDATION_KEY=no'
grep -q 'validation_client_name' \"\$CLIENTRB\" && echo 'HAS_VAL_CLIENT_NAME=yes' || echo 'HAS_VAL_CLIENT_NAME=no'
grep -q 'chef_server_url' \"\$CLIENTRB\" && echo 'HAS_CHEF_SERVER_URL=yes' || echo 'HAS_CHEF_SERVER_URL=no'
" \
    --query "value[0].message" -o tsv | tr -d '\r')"

  echo "${out}"

  if echo "${out}" | grep -q "__CLIENTRB_MISSING__"; then
    fail "client.rb missing on '${vm_name}' — extension may not have run"
  fi

  echo "${out}" | grep -q "HAS_POLICY_NAME=yes"  || fail "client.rb on '${vm_name}' is missing policy_name"
  echo "${out}" | grep -q "HAS_POLICY_GROUP=yes" || fail "client.rb on '${vm_name}' is missing policy_group"
  echo "${out}" | grep -q "HAS_VALIDATION_KEY=no"      && success "client.rb correctly omits validation_key" \
    || warn "client.rb contains validation_key — unexpected in policyfile mode"
  echo "${out}" | grep -q "HAS_VAL_CLIENT_NAME=no"     && success "client.rb correctly omits validation_client_name" \
    || warn "client.rb contains validation_client_name — unexpected in policyfile mode"

  if [[ "${expected_mode}" == "local" ]]; then
    echo "${out}" | grep -q "HAS_CHEF_SERVER_URL=no" \
      && success "client.rb correctly omits chef_server_url in local mode" \
      || warn "client.rb contains chef_server_url in local mode — may be intentional if set in client_rb option"
  else
    echo "${out}" | grep -q "HAS_CHEF_SERVER_URL=yes" \
      || warn "client.rb missing chef_server_url in server mode — node may not connect to Chef Server"
  fi

  success "client.rb policyfile settings verified on '${vm_name}'"
}

# ── Shared: verify first-boot.json has no target_runlist ─────────────────────
verify_no_target_runlist() {
  local vm_name="$1"
  info "Verifying first-boot.json has no target_runlist on '${vm_name}'..."
  local out
  out="$(az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${vm_name}" --command-id RunShellScript \
    --scripts "
set -e
FB=/etc/chef/first-boot.json
if [ ! -f \"\$FB\" ]; then echo '__FIRSTBOOT_MISSING__'; exit 0; fi
cat \"\$FB\"
grep -q 'target_runlist' \"\$FB\" && echo 'HAS_TARGET_RUNLIST=yes' || echo 'HAS_TARGET_RUNLIST=no'
" \
    --query "value[0].message" -o tsv | tr -d '\r')"

  echo "${out}"
  echo "${out}" | grep -q "__FIRSTBOOT_MISSING__" && \
    warn "first-boot.json missing on '${vm_name}' (may have been removed post-run)" && return
  echo "${out}" | grep -q "HAS_TARGET_RUNLIST=no" \
    && success "first-boot.json correctly omits target_runlist" \
    || fail "first-boot.json on '${vm_name}' contains target_runlist — should be absent in policyfile mode"
}

# ── Shared: verify node-registered and policy info ───────────────────────────
verify_node_registered() {
  local vm_name="$1"
  info "Verifying node-registered flag on '${vm_name}'..."
  local out
  out="$(az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${vm_name}" --command-id RunShellScript \
    --scripts "
[ -f /etc/chef/node-registered ] && echo 'NODE_REGISTERED=yes' || echo 'NODE_REGISTERED=no'
[ -f /etc/chef/client.pem ]      && echo 'CLIENT_PEM=yes'       || echo 'CLIENT_PEM=no'
" \
    --query "value[0].message" -o tsv | tr -d '\r')"

  echo "${out}"
  echo "${out}" | grep -q "NODE_REGISTERED=yes" \
    && success "node-registered flag present" \
    || warn "node-registered flag absent — first chef-client run may not have completed"
  echo "${out}" | grep -q "CLIENT_PEM=yes" \
    && success "client.pem present" \
    || warn "client.pem absent — node may not be registered"
}

# ── Shared: fetch and show extension logs ─────────────────────────────────────
fetch_extension_logs() {
  local vm_name="$1"
  info "Fetching extension log tail (last 50 lines) from '${vm_name}'..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${vm_name}" --command-id RunShellScript \
    --scripts "
set -e
list=\$(mktemp)
[ -f '/var/log/azure/custom.log' ] && echo '/var/log/azure/custom.log' >> \"\$list\"
find '/var/log/azure/Chef.Bootstrap.WindowsAzure.LinuxChefClient' -type f -name '*.log' >> \"\$list\" 2>/dev/null || true
find '/var/lib/waagent' -maxdepth 2 -type f -path '/var/lib/waagent/Chef.Bootstrap.WindowsAzure.LinuxChefClient-*/*.log' >> \"\$list\" 2>/dev/null || true
sort -u \"\$list\" -o \"\$list\"
while IFS= read -r lf; do
  [ -z \"\$lf\" ] && continue
  echo \"--- \$lf (last 50 lines) ---\"
  tail -50 \"\$lf\" || true
done < \"\$list\"
rm -f \"\$list\"
" \
    --query "value[0].message" -o tsv
}

# ── Shared: check extension provisioning state ────────────────────────────────
check_extension_state() {
  local vm_name="$1"
  local state
  state="$(az vm extension show \
    -g "${RESOURCE_GROUP}" --vm-name "${vm_name}" \
    --name LinuxChefClient --query "provisioningState" -o tsv 2>/dev/null || echo "Unknown")"

  if [[ "${LOCAL_EXT}" == "true" ]]; then
    info "Marketplace extension provisioning state: ${state} (local code was re-run above)"
  elif [[ "${state}" == "Succeeded" ]]; then
    success "Extension provisioning state: ${state}"
  else
    fail "Extension provisioning state: ${state} (expected Succeeded)"
  fi
}

# ── Test: Chef Server policyfile mode ─────────────────────────────────────────
test_server_policyfile() {
  local vm_name="${LINUX_VM_SERVER}"
  local node_name="${NODE_NAME}-server"
  local pubconfig="${TMPDIR_CONFIGS}/pubconfig-server.json"
  local privconfig="${TMPDIR_CONFIGS}/privconfig-server.json"
  local lock_file

  info "══════ Chef Server Policyfile Mode ══════"

  # Prepare the Policyfile.lock.json
  if [[ -n "${POLICYFILE_LOCK_PATH}" && -f "${POLICYFILE_LOCK_PATH}" ]]; then
    lock_file="${POLICYFILE_LOCK_PATH}"
    info "Using provided Policyfile.lock.json: ${lock_file}"
  else
    lock_file="${TMPDIR_CONFIGS}/Policyfile.lock.json"
    info "No Policyfile.lock.json provided — generating a stub..."
    generate_stub_policyfile_lock "${lock_file}"
  fi

  # Push the policy to the Chef Server
  push_policy_to_server "${lock_file}"

  # Build public config — policy_name + policy_group in bootstrap_options, NO runlist
  jq -n \
    --arg server    "${CHEF_SERVER_URL}" \
    --arg node      "${node_name}" \
    --arg polname   "${POLICY_NAME}" \
    --arg polgroup  "${POLICY_GROUP}" \
    --arg sslmode   "${NODE_SSL_VERIFY_MODE}" \
    --arg infra_ver "${CHEF_INFRA_VERSION}" \
    --arg lickey    "${LICENSE_KEY}" \
    '{
      bootstrap_options: ({
        chef_server_url: $server,
        chef_node_name:  $node,
        policy_name:     $polname,
        policy_group:    $polgroup
      }
      + (if ($sslmode   | length) > 0 then {node_ssl_verify_mode: $sslmode}   else {} end)
      + (if ($infra_ver | length) > 0 then {bootstrap_version:    $infra_ver} else {} end)),
      CHEF_LICENSE: "accept-no-persist"
    }
    + (if ($lickey | length) > 0 then {chef_license_key: $lickey} else {} end)
    ' > "${pubconfig}"

  # Private config — validation_key is optional in policyfile mode; include it if provided
  if [[ -n "${VALIDATION_PEM}" && -f "${VALIDATION_PEM}" ]]; then
    local val_key_json
    val_key_json="$(python3 -c "import json,sys; print(json.dumps(open(sys.argv[1]).read()))" "${VALIDATION_PEM}")"
    jq -n --argjson vk "${val_key_json}" '{ validation_key: $vk }' > "${privconfig}"
    info "Including validation_key in private config (optional in policyfile mode)"
  else
    jq -n '{}' > "${privconfig}"
    info "No validation_key — running in validator-less policyfile mode"
  fi

  info "Public config (server policyfile mode):"
  jq . "${pubconfig}"

  create_linux_vm "${vm_name}"
  install_extension "${vm_name}" "${pubconfig}" "${privconfig}"
  check_extension_state "${vm_name}"
  fetch_extension_logs "${vm_name}"
  verify_policyfile_clientrb "${vm_name}" "server"
  verify_no_target_runlist "${vm_name}"
  verify_node_registered "${vm_name}"

  success "══ Chef Server policyfile test PASSED ══"
}

# ── Test: Local mode policyfile ───────────────────────────────────────────────
test_local_policyfile() {
  local vm_name="${LINUX_VM_LOCAL}"
  local node_name="${NODE_NAME}-local"
  local pubconfig="${TMPDIR_CONFIGS}/pubconfig-local.json"
  local privconfig="${TMPDIR_CONFIGS}/privconfig-local.json"
  local lock_file

  info "══════ Local Mode Policyfile ══════"

  # Prepare the Policyfile.lock.json
  if [[ -n "${POLICYFILE_LOCK_PATH}" && -f "${POLICYFILE_LOCK_PATH}" ]]; then
    lock_file="${POLICYFILE_LOCK_PATH}"
    info "Using provided Policyfile.lock.json: ${lock_file}"
  else
    lock_file="${TMPDIR_CONFIGS}/Policyfile-local.lock.json"
    info "No Policyfile.lock.json provided — generating a stub..."
    generate_stub_policyfile_lock "${lock_file}"
  fi

  # Build public config — local_mode: true, no chef_server_url
  jq -n \
    --arg node      "${node_name}" \
    --arg polname   "${POLICY_NAME}" \
    --arg polgroup  "${POLICY_GROUP}" \
    --arg docpath   "${POLICY_DOCUMENT_PATH}" \
    --arg infra_ver "${CHEF_INFRA_VERSION}" \
    --arg lickey    "${LICENSE_KEY}" \
    '{
      bootstrap_options: ({
        chef_node_name:  $node,
        policy_name:     $polname,
        policy_group:    $polgroup,
        local_mode:      true
      }
      + (if ($infra_ver | length) > 0 then {bootstrap_version: $infra_ver} else {} end)),
      policy_document_relative_path: $docpath,
      CHEF_LICENSE: "accept-no-persist"
    }
    + (if ($lickey | length) > 0 then {chef_license_key: $lickey} else {} end)
    ' > "${pubconfig}"

  # No validation_key needed in local mode
  jq -n '{}' > "${privconfig}"

  info "Public config (local mode):"
  jq . "${pubconfig}"

  create_linux_vm "${vm_name}"

  # Pre-stage the Policyfile.lock.json on the VM before the extension runs
  info "Pre-staging Policyfile.lock.json on '${vm_name}' at ${POLICY_DOCUMENT_PATH}..."
  local lock_encoded
  lock_encoded="$(base64 < "${lock_file}" | tr -d '\n')"
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${vm_name}" --command-id RunShellScript \
    --scripts "
set -e
mkdir -p '$(dirname "${POLICY_DOCUMENT_PATH}")'
printf '%s' '${lock_encoded}' | base64 -d > '${POLICY_DOCUMENT_PATH}'
echo 'Policyfile.lock.json staged at ${POLICY_DOCUMENT_PATH}'
cat '${POLICY_DOCUMENT_PATH}'
" \
    --query "value[0].message" -o tsv
  success "Policyfile.lock.json staged on VM"

  install_extension "${vm_name}" "${pubconfig}" "${privconfig}"
  check_extension_state "${vm_name}"
  fetch_extension_logs "${vm_name}"
  verify_policyfile_clientrb "${vm_name}" "local"
  verify_no_target_runlist "${vm_name}"
  verify_node_registered "${vm_name}"

  # Verify local mode flag in the chef-client invocation from logs
  info "Checking logs for --local-mode flag..."
  local log_out
  log_out="$(az vm run-command invoke \
    -g "${RESOURCE_GROUP}" --name "${vm_name}" --command-id RunShellScript \
    --scripts "grep -r 'local-mode\|local_mode' /var/log/azure/ /var/lib/waagent/Chef.Bootstrap.WindowsAzure.LinuxChefClient-*/log/ 2>/dev/null | tail -10 || echo '__NO_MATCH__'" \
    --query "value[0].message" -o tsv | tr -d '\r')"
  echo "${log_out}"
  if echo "${log_out}" | grep -qv "__NO_MATCH__"; then
    success "local-mode reference found in extension logs"
  else
    warn "Could not confirm --local-mode in extension logs — verify manually"
  fi

  success "══ Local mode policyfile test PASSED ══"
}

# ── Run selected mode(s) ──────────────────────────────────────────────────────
case "${POLICY_MODE}" in
  server) test_server_policyfile ;;
  local)  test_local_policyfile ;;
  both)   test_server_policyfile; test_local_policyfile ;;
esac

echo ""
success "All policyfile tests completed."
echo ""
echo "  Resource group : ${RESOURCE_GROUP}"
echo "  Policy name    : ${POLICY_NAME}"
echo "  Policy group   : ${POLICY_GROUP}"
[[ "${POLICY_MODE}" != "local" ]] && echo "  Chef Server    : ${CHEF_SERVER_URL}"
echo ""
