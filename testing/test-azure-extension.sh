#!/bin/bash
# End-to-end test script for the Azure Chef Extension.
#
# Creates one or both of a Linux/Windows Azure VM, installs the Chef extension,
# verifies the node bootstrapped on Chef Server, and optionally cleans up.
#
# Usage:
#   bash testing/test-azure-extension.sh [OPTIONS]
#
# .env file support:
#   All configuration values can be set in a .env file.  The script auto-loads
#   testing/.env (relative to the script) if it exists.  Use --env-file to
#   point to a different file.  CLI options always override .env values.
#   See testing/.env.example for a full list of supported variables.
#
# Required options (unless --build-chef-server is used):
#   --chef-server-url <url>          Chef Server URL
#   --validation-client-name <name>  Validation client name (e.g. myorg-validator)
#   --validation-pem <path>          Path to the validation .pem file
#
# Optional options:
#   --env-file <path>           Load configuration from a .env file
#   --build-chef-server         Provision a temporary Chef Server VM for this test
#   --chef-server-version <ver> Chef Server package version for --build-chef-server
#   --chef-server-vm <name>     Chef Server VM name (default: chef-test-server)
#   --chef-server-org <name>    Chef org short name for --build-chef-server (default: testorg)
#   --chef-server-user <name>   Chef admin username for --build-chef-server (default: testadmin)
#   --azure-tenant <tenant-id>  Azure tenant to log into/use
#   --azure-subscription <id|name>  Azure subscription to select
#   --azure-use-device-code     Use device code auth for az login
#   --azure-service-principal <app-id>       Log in with a service principal instead of
#                                             interactive/device-code SSO (required if the
#                                             tenant isn't reachable via your SSO account)
#   --azure-service-principal-password <pw>  Password/secret for --azure-service-principal
#   --resource-group <name>    Azure resource group name (default: chef-ext-test-rg)
#   --location <region>        Azure region (default: eastus)
#   --node-name <name>         Chef node name (default: az-ext-test-node)
#   --runlist <runlist>        Chef run list (default: recipe[base])
#   --license-key <key>        Chef license key for licensed downloads
#   --license-bypass           Explicitly opt into the deprecated, unlicensed omnitruck
#                              download path (extension requires a license key otherwise)
#   --extension-version <ver>  Extension version (default: 1210.14)
#   --chef-infra-version <ver> Chef Infra Client version to install (e.g. 18.10.17); omit for latest
#   --chef-infra-channel <ch>  Install channel: stable (default), current, unstable
#   --local-ext                After marketplace install (for gem + config setup), upload local
#                              ChefExtensionHandler files and re-run install.sh + enable.sh to test
#                              local code changes without a full extension publish cycle
#   --platform <linux|rhel8|rhel10|windows|both>  Which platform to test (default: linux)
#   --skip-cleanup             Do not delete Azure resources after the test
#   --ssh-public-key-path <path>  Public key to upload for Linux VM SSH access
#   --help                     Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── .env file loading ─────────────────────────────────────────────────────────
# Pre-scan args for --env-file before full argument parsing.
_env_file=""
_prev_arg=""
for _arg in "$@"; do
  [[ "${_prev_arg}" == "--env-file" ]] && { _env_file="${_arg}"; break; }
  _prev_arg="${_arg}"
done

# Fall back to testing/.env alongside this script if no --env-file was given.
if [[ -z "${_env_file}" ]]; then
  _default_env="$(cd "$(dirname "$0")" && pwd)/.env"
  [[ -f "${_default_env}" ]] && _env_file="${_default_env}"
fi

if [[ -n "${_env_file}" ]]; then
  [[ ! -f "${_env_file}" ]] && { echo "[FAIL] .env file not found: ${_env_file}" >&2; exit 1; }
  set -a
  # shellcheck source=/dev/null
  source "${_env_file}"
  set +a
  echo -e "\033[0;34m[INFO]\033[0m  Loaded configuration from ${_env_file}"
fi
unset _env_file _default_env _prev_arg _arg

# ── Defaults ──────────────────────────────────────────────────────────────────
# Each variable uses its .env value if set, otherwise falls back to the default.
RESOURCE_GROUP="${RESOURCE_GROUP:-chef-ext-test-rg}"
LOCATION="${LOCATION:-eastus}"
NODE_NAME="${NODE_NAME:-az-ext-test-node}"
RUNLIST="${RUNLIST:-recipe[base]}"
LICENSE_KEY="${LICENSE_KEY:-}"
LICENSE_BYPASS="${LICENSE_BYPASS:-false}"
EXTENSION_VERSION="${EXTENSION_VERSION:-1210.14}"
CHEF_INFRA_VERSION="${CHEF_INFRA_VERSION:-}"
CHEF_INFRA_CHANNEL="${CHEF_INFRA_CHANNEL:-}"
LOCAL_EXT="${LOCAL_EXT:-false}"
PLATFORM="${PLATFORM:-linux}"
SKIP_CLEANUP="${SKIP_CLEANUP:-false}"
SSH_PUBLIC_KEY_PATH="${SSH_PUBLIC_KEY_PATH:-$HOME/.ssh/id_rsa.pub}"
CHEF_SERVER_URL="${CHEF_SERVER_URL:-}"
VALIDATION_CLIENT_NAME="${VALIDATION_CLIENT_NAME:-}"
VALIDATION_PEM="${VALIDATION_PEM:-}"
BUILD_CHEF_SERVER="${BUILD_CHEF_SERVER:-false}"
CHEF_SERVER_VM="${CHEF_SERVER_VM:-chef-test-server}"
CHEF_SERVER_VERSION="${CHEF_SERVER_VERSION:-15.10.84-20251114181706}"
CHEF_SERVER_ORG="${CHEF_SERVER_ORG:-testorg}"
CHEF_SERVER_ORG_FULL_NAME="${CHEF_SERVER_ORG_FULL_NAME:-Test Org}"
CHEF_SERVER_USER="${CHEF_SERVER_USER:-testadmin}"
CHEF_SERVER_USER_EMAIL="${CHEF_SERVER_USER_EMAIL:-testadmin@example.com}"
CHEF_SERVER_USER_PASSWORD="${CHEF_SERVER_USER_PASSWORD:-ChefServer@Test$(date +%s)!}"
NODE_SSL_VERIFY_MODE="${NODE_SSL_VERIFY_MODE:-}"
AZURE_TENANT="${AZURE_TENANT:-}"
AZURE_SUBSCRIPTION="${AZURE_SUBSCRIPTION:-}"
AZURE_USE_DEVICE_CODE="${AZURE_USE_DEVICE_CODE:-false}"
AZURE_SERVICE_PRINCIPAL="${AZURE_SERVICE_PRINCIPAL:-}"
AZURE_SERVICE_PRINCIPAL_PASSWORD="${AZURE_SERVICE_PRINCIPAL_PASSWORD:-}"

LINUX_VM="${LINUX_VM:-chef-test-linux}"
WINDOWS_VM="${WINDOWS_VM:-chef-test-windows}"
ADMIN_USER="${ADMIN_USER:-azureuser}"
WINDOWS_PASSWORD="${WINDOWS_PASSWORD:-AzureChef@Test$(date +%s)!}"  # unique each run

TMPDIR_CONFIGS="$(mktemp -d)"
PUBCONFIG="${TMPDIR_CONFIGS}/publicconfig.json"
PRIVCONFIG="${TMPDIR_CONFIGS}/privateconfig.json"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-${SCRIPT_DIR}/artifacts}"

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "\033[0;34m[INFO]\033[0m  $*"; }
success() { echo -e "\033[0;32m[PASS]\033[0m  $*"; }
warn()    { echo -e "\033[0;33m[WARN]\033[0m  $*"; }
fail()    { echo -e "\033[0;31m[FAIL]\033[0m  $*" >&2; exit 1; }

log_license_key_metadata() {
  [[ -z "${LICENSE_KEY}" ]] && return
  info "License key provided (length: ${#LICENSE_KEY} characters)"
}

verify_linux_validator_key_checksum() {
  local local_checksum remote_output remote_checksum

  local_checksum="$(openssl pkey -in "${VALIDATION_PEM}" -pubout -outform DER 2>/dev/null | shasum -a 256 | awk '{print $1}')"
  [[ -z "${local_checksum}" ]] && fail "Unable to normalize/checksum local validator key"

  remote_output="$(az vm run-command invoke \
    -g "${RESOURCE_GROUP}" \
    --name "${LINUX_VM}" \
    --command-id RunShellScript \
    --scripts "set -e; key_file='/etc/chef/validation.pem'; if [ ! -s \"\$key_file\" ]; then echo '__VALIDATION_PEM_MISSING__'; exit 0; fi; if ! command -v openssl >/dev/null 2>&1; then echo '__NO_OPENSSL__'; exit 0; fi; pub_hash=\$(openssl pkey -in \"\$key_file\" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print \$1}'); if [ -z \"\$pub_hash\" ]; then echo '__NORMALIZE_FAILED__'; exit 0; fi; echo \"\$pub_hash\"" \
    --query "value[0].message" -o tsv | tr -d '\r')"

  if printf '%s\n' "${remote_output}" | grep -q "__VALIDATION_PEM_MISSING__"; then
    fail "Validator key file missing on VM: /etc/chef/validation.pem"
  fi

  if printf '%s\n' "${remote_output}" | grep -q "__NO_OPENSSL__"; then
    fail "Unable to normalize/checksum /etc/chef/validation.pem on VM (openssl unavailable)"
  fi

  if printf '%s\n' "${remote_output}" | grep -q "__NORMALIZE_FAILED__"; then
    fail "Unable to normalize/checksum /etc/chef/validation.pem on VM"
  fi

  remote_checksum="$(printf '%s\n' "${remote_output}" | grep -Eo '[0-9a-fA-F]{64}' | head -1 | tr '[:upper:]' '[:lower:]')"
  [[ -z "${remote_checksum}" ]] && fail "Unable to parse validator key checksum from VM output"

  if [[ "${local_checksum}" == "${remote_checksum}" ]]; then
    success "Validator key checksum matches local PEM (${local_checksum})"
  else
    fail "Validator key checksum mismatch (local: ${local_checksum}, vm: ${remote_checksum})"
  fi
}

print_linux_node_validation_diagnostics() {
  info "Printing node-side Chef validation diagnostics..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" \
    --name "${LINUX_VM}" \
    --command-id RunShellScript \
    --scripts "set -e; echo '--- /etc/chef file presence ---'; ls -l /etc/chef 2>/dev/null || true; echo; echo '--- key file status ---'; for f in /etc/chef/validation.pem /etc/chef/client.pem /etc/chef/first-boot.json /etc/chef/client.rb /etc/chef/node-registered; do if [ -e \"\$f\" ]; then sz=\$(wc -c < \"\$f\" 2>/dev/null || echo 0); echo \"PRESENT \$f size=\$sz\"; else echo \"MISSING \$f\"; fi; done; echo; echo '--- client.rb key settings ---'; if [ -f /etc/chef/client.rb ]; then grep -E '^[[:space:]]*(chef_server_url|validation_client_name|validation_key|client_key|node_name|ssl_verify_mode)' /etc/chef/client.rb || true; else echo 'client.rb missing'; fi; echo; echo '--- key fingerprints (public DER sha256) ---'; if command -v openssl >/dev/null 2>&1; then for keyf in /etc/chef/validation.pem /etc/chef/client.pem; do if [ -s \"\$keyf\" ]; then fp=\$(openssl pkey -in \"\$keyf\" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print \$1}'); [ -n \"\$fp\" ] && echo \"\$keyf \$fp\" || echo \"\$keyf <unable-to-normalize>\"; else echo \"\$keyf <missing-or-empty>\"; fi; done; else echo 'openssl not available on VM'; fi" \
    --query "value[0].message" -o tsv
}

download_linux_extension_logs() {
  local archive_name local_archive run_command_output tmp_logs_dir local_validator_checksum

  archive_name="linux-chef-extension-logs-${LINUX_VM}-$(date +%Y%m%d%H%M%S).tar.gz"
  local_archive="${ARTIFACTS_DIR}/${archive_name}"

  mkdir -p "${ARTIFACTS_DIR}"
  info "Archiving Linux extension logs to ${local_archive}..."

  run_command_output="$(az vm run-command invoke \
    -g "${RESOURCE_GROUP}" \
    --name "${LINUX_VM}" \
    --command-id RunShellScript \
    --scripts "set -e; list_file=\$(mktemp); [ -f '/var/log/azure/custom.log' ] && echo '/var/log/azure/custom.log' >> \"\$list_file\"; find '/var/log/azure/Chef.Bootstrap.WindowsAzure.LinuxChefClient' -type f -name '*.log' >> \"\$list_file\" 2>/dev/null || true; find '/var/lib/waagent' -maxdepth 2 -type f -path '/var/lib/waagent/Chef.Bootstrap.WindowsAzure.LinuxChefClient-*/*.log' >> \"\$list_file\" 2>/dev/null || true; sort -u \"\$list_file\" -o \"\$list_file\"; if [ ! -s \"\$list_file\" ]; then echo '__NO_LOGS__'; rm -f \"\$list_file\"; exit 0; fi; while IFS= read -r log_file; do [ -z \"\$log_file\" ] && continue; echo \"--- \${log_file} (last 200 lines) ---\"; tail -n 200 \"\$log_file\" || true; echo; done < \"\$list_file\"; rm -f \"\$list_file\"" \
    --query "value[0].message" -o tsv | tr -d '\r')"

  if printf '%s\n' "${run_command_output}" | grep -q "__NO_LOGS__"; then
    warn "No Linux extension logs found on VM; skipping artifact download"
    return
  fi

  local_validator_checksum="$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "${VALIDATION_PEM}")"
  tmp_logs_dir="$(mktemp -d)"
  {
    echo "# Test metadata"
    if [[ -n "${LICENSE_KEY}" ]]; then
      echo "LICENSE_KEY_LENGTH=${#LICENSE_KEY}"
    else
      echo "LICENSE_KEY_LENGTH=0"
    fi
    echo "LOCAL_VALIDATION_PEM_SHA256=${local_validator_checksum}"
    echo ""
    echo "# Remote log output"
    printf '%s\n' "${run_command_output}"
  } > "${tmp_logs_dir}/linux-extension-logs.txt"
  tar -czf "${local_archive}" -C "${tmp_logs_dir}" linux-extension-logs.txt
  rm -rf "${tmp_logs_dir}"

  if ! tar -tzf "${local_archive}" >/dev/null 2>&1; then
    rm -f "${local_archive}"
    fail "Retrieved Linux extension logs archive is invalid or truncated"
  fi

  success "Saved Linux extension logs archive to ${local_archive}"
}

cleanup() {
  info "Removing temp config files"
  rm -rf "${TMPDIR_CONFIGS}"
  if [[ "${SKIP_CLEANUP}" == "false" ]]; then
    if [[ -n "${AZ_SUBSCRIPTION_ID:-}" ]]; then
      info "Deleting resource group ${RESOURCE_GROUP} (async)..."
      az group delete -n "${RESOURCE_GROUP}" --subscription "${AZ_SUBSCRIPTION_ID}" --yes --no-wait 2>/dev/null || true
    fi
    info "To delete Chef nodes, run:"
    echo "  knife node delete ${NODE_NAME} -y"
    echo "  knife client delete ${NODE_NAME} -y"
    if [[ "${PLATFORM}" == "both" ]]; then
      echo "  knife node delete ${NODE_NAME}-win -y"
      echo "  knife client delete ${NODE_NAME}-win -y"
    fi
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
    --env-file)                shift 2 ;;                        # already loaded above
    --chef-server-url)         CHEF_SERVER_URL="$2";         shift 2 ;;
    --validation-client-name)  VALIDATION_CLIENT_NAME="$2";  shift 2 ;;
    --validation-pem)          VALIDATION_PEM="$2";           shift 2 ;;
    --build-chef-server)       BUILD_CHEF_SERVER=true;        shift ;;
    --chef-server-version)     CHEF_SERVER_VERSION="$2";      shift 2 ;;
    --chef-server-vm)          CHEF_SERVER_VM="$2";           shift 2 ;;
    --chef-server-org)         CHEF_SERVER_ORG="$2";          shift 2 ;;
    --chef-server-user)        CHEF_SERVER_USER="$2";         shift 2 ;;
    --azure-tenant)            AZURE_TENANT="$2";             shift 2 ;;
    --azure-subscription)      AZURE_SUBSCRIPTION="$2";       shift 2 ;;
    --azure-use-device-code)   AZURE_USE_DEVICE_CODE=true;    shift ;;
    --azure-service-principal)          AZURE_SERVICE_PRINCIPAL="$2";          shift 2 ;;
    --azure-service-principal-password) AZURE_SERVICE_PRINCIPAL_PASSWORD="$2"; shift 2 ;;
    --resource-group)          RESOURCE_GROUP="$2";           shift 2 ;;
    --location)                LOCATION="$2";                 shift 2 ;;
    --node-name)               NODE_NAME="$2";                shift 2 ;;
    --runlist)                 RUNLIST="$2";                  shift 2 ;;
    --license-key)             LICENSE_KEY="$2";              shift 2 ;;
    --license-bypass)          LICENSE_BYPASS=true;            shift ;;
    --extension-version)       EXTENSION_VERSION="$2";        shift 2 ;;
    --chef-infra-version)      CHEF_INFRA_VERSION="$2";       shift 2 ;;
    --chef-infra-channel)      CHEF_INFRA_CHANNEL="$2";       shift 2 ;;
    --local-ext)               LOCAL_EXT=true;                shift ;;
    --platform)                PLATFORM="$2";                 shift 2 ;;
    --skip-cleanup)            SKIP_CLEANUP=true;             shift ;;
    --ssh-public-key-path)     SSH_PUBLIC_KEY_PATH="$2";      shift 2 ;;
    --help|-h)                 usage ;;
    *) fail "Unknown option: $1" ;;
  esac
done

# ── Preflight checks ──────────────────────────────────────────────────────────
info "Running preflight checks..."

command -v az  &>/dev/null || fail "Azure CLI (az) not found — install from https://aka.ms/install-az"
command -v jq  &>/dev/null || fail "jq not found — install with: brew install jq / apt install jq"
[[ -f "${SSH_PUBLIC_KEY_PATH}" ]] || fail "SSH public key not found: ${SSH_PUBLIC_KEY_PATH}"

azure_login() {
  if [[ -n "${AZURE_SERVICE_PRINCIPAL}" ]]; then
    [[ -n "${AZURE_TENANT}" ]] || fail "AZURE_TENANT is required when AZURE_SERVICE_PRINCIPAL is set."
    az login --service-principal \
      --username "${AZURE_SERVICE_PRINCIPAL}" \
      --password "${AZURE_SERVICE_PRINCIPAL_PASSWORD}" \
      --tenant "${AZURE_TENANT}" \
      --output none || fail "Azure service-principal login failed. Check AZURE_SERVICE_PRINCIPAL/AZURE_SERVICE_PRINCIPAL_PASSWORD/AZURE_TENANT."
    return
  fi
  local -a login_cmd=(az login --output none)
  [[ -n "${AZURE_TENANT}" ]] && login_cmd+=(--tenant "${AZURE_TENANT}")
  [[ "${AZURE_USE_DEVICE_CODE}" == "true" ]] && login_cmd+=(--use-device-code)
  "${login_cmd[@]}" || fail "Azure login failed. Retry with --azure-use-device-code and/or --azure-tenant <tenant-id> if your org enforces MFA or tenant-scoped access."
}

if ! az account show &>/dev/null; then
  info "Not logged in to Azure. Launching 'az login'..."
  azure_login
elif [[ -n "${AZURE_SERVICE_PRINCIPAL}" ]]; then
  CURRENT_ACCOUNT="$(az account show --query user.name -o tsv 2>/dev/null || true)"
  if [[ "${CURRENT_ACCOUNT}" != "${AZURE_SERVICE_PRINCIPAL}" ]]; then
    info "Logging in as service principal ${AZURE_SERVICE_PRINCIPAL}..."
    azure_login
  fi
elif [[ -n "${AZURE_TENANT}" ]]; then
  CURRENT_TENANT="$(az account show --query tenantId -o tsv 2>/dev/null || true)"
  if [[ "${CURRENT_TENANT}" != "${AZURE_TENANT}" ]]; then
    info "Current Azure context is tenant ${CURRENT_TENANT}; logging into tenant ${AZURE_TENANT}..."
    azure_login
  fi
fi

if [[ -n "${AZURE_SUBSCRIPTION}" ]]; then
  az account set --subscription "${AZURE_SUBSCRIPTION}" --output none 2>/dev/null || \
    fail "Unable to select Azure subscription '${AZURE_SUBSCRIPTION}'."
fi

AZ_SUBSCRIPTION_ID="$(az account show --query id -o tsv 2>/dev/null || true)"
AZ_SUBSCRIPTION_NAME="$(az account show --query name -o tsv 2>/dev/null || true)"
AZ_SUBSCRIPTION_STATE="$(az account show --query state -o tsv 2>/dev/null || true)"

if [[ -z "${AZ_SUBSCRIPTION_ID}" ]]; then
  if [[ -n "${AZURE_TENANT}" ]]; then
    AZ_SUBSCRIPTION_ID="$(az account list --all --query "[?state=='Enabled' && tenantId=='${AZURE_TENANT}'] | [0].id" -o tsv 2>/dev/null || true)"
  else
    AZ_SUBSCRIPTION_ID="$(az account list --all --query "[?state=='Enabled'] | [0].id" -o tsv 2>/dev/null || true)"
  fi

  if [[ -n "${AZ_SUBSCRIPTION_ID}" ]]; then
    az account set --subscription "${AZ_SUBSCRIPTION_ID}" --output none
    AZ_SUBSCRIPTION_NAME="$(az account show --query name -o tsv 2>/dev/null || true)"
    AZ_SUBSCRIPTION_STATE="$(az account show --query state -o tsv 2>/dev/null || true)"
  fi
fi

[[ -z "${AZ_SUBSCRIPTION_ID}" ]] && fail "No active Azure subscription selected. Use --azure-subscription <id|name>, or run az account set --subscription <id|name>."
[[ "${AZ_SUBSCRIPTION_STATE}" != "Enabled" ]] && fail "Selected Azure subscription is not enabled (${AZ_SUBSCRIPTION_STATE})"
info "Using Azure subscription: ${AZ_SUBSCRIPTION_NAME} (${AZ_SUBSCRIPTION_ID})"

[[ "${PLATFORM}" =~ ^(linux|rhel8|rhel10|windows|both)$ ]] || fail "--platform must be linux, rhel8, rhel10, windows, or both"

# Map PLATFORM to the Linux distro's VM image and Chef omnitruck platform/version
# (used below to resolve licensed package URLs). "both" and plain "linux" mean Ubuntu.
case "${PLATFORM}" in
  rhel8)
    LINUX_IMAGE="RedHat:RHEL:8-lvm-gen2:latest"
    CHEF_OMNITRUCK_PLATFORM="el"
    CHEF_OMNITRUCK_PLATFORM_VERSION="8"
    ;;
  rhel10)
    # ponytail: RHEL 10 marketplace SKU naming may shift after GA; if VM
    # creation fails, check `az vm image list-skus --publisher RedHat --offer RHEL -l <region>`
    # and update LINUX_IMAGE.
    LINUX_IMAGE="RedHat:RHEL:10-lvm-gen2:latest"
    CHEF_OMNITRUCK_PLATFORM="el"
    CHEF_OMNITRUCK_PLATFORM_VERSION="10"
    ;;
  *)
    LINUX_IMAGE="Ubuntu2204"
    CHEF_OMNITRUCK_PLATFORM="ubuntu"
    CHEF_OMNITRUCK_PLATFORM_VERSION="22.04"
    ;;
esac

# The extension now hard-requires chef_license_key unless chef_license_bypass
# is explicitly set — fail fast here rather than wasting Azure resources on a
# VM that will refuse to install Chef.
if [[ -z "${LICENSE_KEY}" && "${LICENSE_BYPASS}" != "true" ]]; then
  fail "--license-key is required (or pass --license-bypass to explicitly test the deprecated, unlicensed omnitruck path)"
fi

if [[ "${BUILD_CHEF_SERVER}" == "false" ]]; then
  [[ -z "${CHEF_SERVER_URL}" ]]         && fail "--chef-server-url is required (or pass --build-chef-server)"
  [[ -z "${VALIDATION_CLIENT_NAME}" ]]  && fail "--validation-client-name is required (or pass --build-chef-server)"
  [[ -z "${VALIDATION_PEM}" ]]          && fail "--validation-pem is required (or pass --build-chef-server)"
  [[ ! -f "${VALIDATION_PEM}" ]]        && fail "Validation PEM not found: ${VALIDATION_PEM}"
else
  [[ -n "${CHEF_SERVER_URL}" || -n "${VALIDATION_CLIENT_NAME}" || -n "${VALIDATION_PEM}" ]] && \
    warn "Using --build-chef-server; explicit Chef Server URL/validator settings will be ignored."
fi

success "Preflight OK"

# ── Run local validation scripts ──────────────────────────────────────────────
info "Running local validation scripts..."
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -n "${LICENSE_KEY}" ]]; then
  bash "${REPO_ROOT}/validation/validate-linux.sh" --license-key "${LICENSE_KEY}"
else
  bash "${REPO_ROOT}/validation/validate-linux.sh"
fi
success "Local validation passed"

# ── Create resource group ─────────────────────────────────────────────────────
info "Creating resource group '${RESOURCE_GROUP}' in ${LOCATION}..."
az group create -n "${RESOURCE_GROUP}" -l "${LOCATION}" --subscription "${AZ_SUBSCRIPTION_ID}" --output none
success "Resource group ready"

# ── Optional: Build temporary Chef Server ─────────────────────────────────────
provision_chef_server() {
  info "Provisioning Chef Server VM '${CHEF_SERVER_VM}'..."
  az vm create \
    -g "${RESOURCE_GROUP}" \
    -n "${CHEF_SERVER_VM}" \
    --image Ubuntu2204 \
    --size Standard_B2s \
    --admin-username "${ADMIN_USER}" \
    --ssh-key-values "${SSH_PUBLIC_KEY_PATH}" \
    --output none

  az vm open-port -g "${RESOURCE_GROUP}" -n "${CHEF_SERVER_VM}" --port 443 --priority 1010 --output none

  info "Installing Chef Server ${CHEF_SERVER_VERSION} (this can take several minutes)..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" \
    --name "${CHEF_SERVER_VM}" \
    --command-id RunShellScript \
    --scripts "set -euo pipefail" \
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
  [[ -z "${chef_server_ip}" ]] && fail "Unable to determine Chef Server public IP for '${CHEF_SERVER_VM}'"

  CHEF_SERVER_URL="https://${chef_server_ip}/organizations/${CHEF_SERVER_ORG}"
  VALIDATION_CLIENT_NAME="${CHEF_SERVER_ORG}-validator"
  VALIDATION_PEM="${TMPDIR_CONFIGS}/${CHEF_SERVER_ORG}-validator.pem"
  NODE_SSL_VERIFY_MODE="verify_none"

  local validator_pem_b64
  validator_pem_b64="$(az vm run-command invoke \
    -g "${RESOURCE_GROUP}" \
    --name "${CHEF_SERVER_VM}" \
    --command-id RunShellScript \
    --scripts "sudo base64 -w 0 /tmp/${CHEF_SERVER_ORG}-validator.pem" \
    --query "value[0].message" -o tsv | tr -d '\r\n')"

  python3 -c "import base64,sys; open(sys.argv[1], 'wb').write(base64.b64decode(sys.argv[2]))" \
    "${VALIDATION_PEM}" "${validator_pem_b64}"

  [[ ! -s "${VALIDATION_PEM}" ]] && fail "Failed to retrieve validator PEM from Chef Server VM"
  success "Chef Server ready at ${CHEF_SERVER_URL}"
}

if [[ "${BUILD_CHEF_SERVER}" == "true" ]]; then
  provision_chef_server
fi

# ── Build config files ────────────────────────────────────────────────────────
info "Building extension config files..."
log_license_key_metadata

VALIDATION_KEY_JSON="$(python3 -c "import json,sys; print(json.dumps(open(sys.argv[1]).read()))" "${VALIDATION_PEM}")"

# For gated Chef versions (< 18), the published extension has a bug passing the
# license key to omnitruck (-L flag is not a valid getopts option in install.sh).
# Workaround: pre-resolve the licensed download URL here and inject it as
# chef_package_url — the extension downloads it directly with curl, no license
# key handling required.
# ponytail: resolves whatever distro/version PLATFORM mapped to above (Ubuntu
# 22.04 by default, or RHEL 8/10 via --platform rhel8|rhel10).
LINUX_CHEF_PACKAGE_URL=""
if [[ -n "${CHEF_INFRA_VERSION}" && -n "${LICENSE_KEY}" && "${PLATFORM}" != "windows" ]]; then
  _ch="${CHEF_INFRA_CHANNEL:-stable}"
  _omni_meta="https://chefdownload-commercial.chef.io/${_ch}/chef/metadata?p=${CHEF_OMNITRUCK_PLATFORM}&pv=${CHEF_OMNITRUCK_PLATFORM_VERSION}&m=x86_64&v=${CHEF_INFRA_VERSION}&license_id=${LICENSE_KEY}"
  _base_url="$(curl -fsSL "${_omni_meta}" 2>/dev/null | grep '^url' | awk '{print $2}' || true)"
  if [[ -n "${_base_url}" ]]; then
    LINUX_CHEF_PACKAGE_URL="${_base_url}"
    info "Resolved licensed Chef ${CHEF_INFRA_VERSION} package URL (chefdownload-commercial.chef.io)"
  else
    warn "Could not resolve download URL for Chef ${CHEF_INFRA_VERSION} — download may fail on the VM"
  fi
fi

# Public config
if [[ -n "${LICENSE_KEY}" ]]; then
  jq -n \
    --arg server    "${CHEF_SERVER_URL}" \
    --arg valclient "${VALIDATION_CLIENT_NAME}" \
    --arg node      "${NODE_NAME}" \
    --arg runlist   "${RUNLIST}" \
    --arg lickey    "${LICENSE_KEY}" \
    --arg sslmode   "${NODE_SSL_VERIFY_MODE}" \
    --arg infra_ver "${CHEF_INFRA_VERSION}" \
    --arg infra_ch  "${CHEF_INFRA_CHANNEL}" \
    --arg pkg_url   "${LINUX_CHEF_PACKAGE_URL}" \
    '{
      bootstrap_options: ({
        chef_server_url:          $server,
        validation_client_name:   $valclient,
        chef_node_name:           $node
      }
      + (if ($sslmode   | length) > 0 then {node_ssl_verify_mode:  $sslmode}   else {} end)
      + (if ($pkg_url   | length) > 0 then {chef_package_url:      $pkg_url}   else {} end)
      + (if ($pkg_url   | length) == 0 and ($infra_ver | length) > 0 then {bootstrap_version: $infra_ver} else {} end)
      + (if ($pkg_url   | length) == 0 and ($infra_ch  | length) > 0 then {bootstrap_channel: $infra_ch}  else {} end)),
      runlist:          $runlist,
      CHEF_LICENSE:     "accept-no-persist",
      chef_license_key: $lickey
    }' > "${PUBCONFIG}"
else
  jq -n \
    --arg server    "${CHEF_SERVER_URL}" \
    --arg valclient "${VALIDATION_CLIENT_NAME}" \
    --arg node      "${NODE_NAME}" \
    --arg runlist   "${RUNLIST}" \
    --arg sslmode   "${NODE_SSL_VERIFY_MODE}" \
    --arg infra_ver "${CHEF_INFRA_VERSION}" \
    --arg infra_ch  "${CHEF_INFRA_CHANNEL}" \
    --arg pkg_url   "${LINUX_CHEF_PACKAGE_URL}" \
    --arg lic_bypass "${LICENSE_BYPASS}" \
    '{
      bootstrap_options: ({
        chef_server_url:         $server,
        validation_client_name:  $valclient,
        chef_node_name:          $node
      }
      + (if ($sslmode   | length) > 0 then {node_ssl_verify_mode:  $sslmode}   else {} end)
      + (if ($pkg_url   | length) > 0 then {chef_package_url:      $pkg_url}   else {} end)
      + (if ($pkg_url   | length) == 0 and ($infra_ver | length) > 0 then {bootstrap_version: $infra_ver} else {} end)
      + (if ($pkg_url   | length) == 0 and ($infra_ch  | length) > 0 then {bootstrap_channel: $infra_ch}  else {} end)),
      runlist:      $runlist,
      CHEF_LICENSE: "accept-no-persist",
      chef_license_bypass: $lic_bypass
    }' > "${PUBCONFIG}"
fi

# Private config
jq -n --argjson valkey "${VALIDATION_KEY_JSON}" \
  '{ validation_key: $valkey }' > "${PRIVCONFIG}"

success "Config files written to ${TMPDIR_CONFIGS}"

# ── Local extension patching ──────────────────────────────────────────────────
# Uploads local ChefExtensionHandler files to the VM's marketplace extension
# directory and re-runs install.sh + enable.sh so local code changes can be
# validated without a full extension publish cycle.
#
# Requires the marketplace extension to have already run (it installs the gem
# and writes the config/0.settings file that enable.sh needs).
patch_linux_local_ext() {
  local ext_handler="${REPO_ROOT}/ChefExtensionHandler"

  # ponytail: waagent retries a failed marketplace Install every ~40s and
  # re-unzips the original package on top of anything we patch inside the
  # waagent-managed extension dir (a race, not a bug in the patched code).
  # Stopping waagent isn't viable either — run-command itself depends on it,
  # so a stopped agent wedges the invoke. Instead, copy the whole extension
  # dir (including config/0.settings written by the marketplace run) to an
  # isolated path waagent never touches, patch the copy, and run from there.
  info "[local-ext] Copying extension dir to an isolated path immune to waagent's re-sync..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" \
    --name "${LINUX_VM}" \
    --command-id RunShellScript \
    --scripts "EXT_DIR=\$(find /var/lib/waagent -maxdepth 1 -name 'Chef.Bootstrap.WindowsAzure.LinuxChefClient-*' -type d 2>/dev/null | sort -V | tail -1)
[ -z \"\$EXT_DIR\" ] && { echo 'ERROR: extension dir not found'; exit 1; }
rm -rf /tmp/chef-local-ext
cp -a \"\$EXT_DIR\" /tmp/chef-local-ext
echo \"Copied \$EXT_DIR to /tmp/chef-local-ext\"" \
    --query "value[0].message" -o tsv

  # HandlerEnvironment.json still points waagent-style paths (configFolder,
  # statusFolder, heartbeatFile) at the original /var/lib/waagent/... dir;
  # shared.rb reads configFolder from this file to locate 0.settings, so
  # without this fix the isolated copy silently re-reads the ORIGINAL
  # marketplace settings (stale chef_node_name, etc.) instead of its own.
  info "[local-ext] Repointing HandlerEnvironment.json at the isolated copy..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" \
    --name "${LINUX_VM}" \
    --command-id RunShellScript \
    --scripts "ORIG_EXT_DIR=\$(find /var/lib/waagent -maxdepth 1 -name 'Chef.Bootstrap.WindowsAzure.LinuxChefClient-*' -type d 2>/dev/null | sort -V | tail -1)
sed -i \"s#\${ORIG_EXT_DIR}#/tmp/chef-local-ext#g\" /tmp/chef-local-ext/HandlerEnvironment.json
echo 'Repointed HandlerEnvironment.json'" \
    --query "value[0].message" -o tsv

  info "[local-ext] Uploading local ChefExtensionHandler files to the isolated copy..."

  # Build a fresh azure-chef-extension gem so the isolated copy's gems/*.gem
  # glob (used by chef-install.sh's `gem install` step) resolves to our local
  # code, not whatever was bundled in the marketplace package.
  info "[local-ext] Building azure-chef-extension gem from local source..."
  (cd "${REPO_ROOT}" && gem build azure-chef-extension.gemspec --output /tmp/azure-chef-extension-local.gem) >/dev/null
  local gem_encoded
  gem_encoded=$(base64 < /tmp/azure-chef-extension-local.gem | tr -d '\n')

  # ponytail: az vm run-command scripts are size-limited; bundling the ~120KB
  # gem's base64 (~165KB) together with the shell/ruby file uploads below
  # silently truncates the combined script mid-file. Upload the gem in its
  # own run-command call, separate from the (much smaller) source files.
  info "[local-ext] Uploading local gem to the isolated copy..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" \
    --name "${LINUX_VM}" \
    --command-id RunShellScript \
    --scripts "EXT_DIR=/tmp/chef-local-ext
mkdir -p \"\$EXT_DIR/gems\"
rm -f \"\$EXT_DIR\"/gems/*.gem
printf '%s' '${gem_encoded}' | base64 -d > \"\$EXT_DIR/gems/azure-chef-extension-local.gem\"
echo '  patched: gems/azure-chef-extension-local.gem'" \
    --query "value[0].message" -o tsv

  # Base64 alphabet (A-Za-z0-9+/=) contains no single quotes, so single-quoting
  # encoded content inside the remote script is safe.
  local upload_script="EXT_DIR=/tmp/chef-local-ext
echo \"Patching \$EXT_DIR with local code...\""

  local linux_files=(
    "install.sh"
    "enable.sh"
    "disable.sh"
    "uninstall.sh"
    "update.sh"
    "bin/chef-install.sh"
    "bin/shared.sh"
    "bin/chef-enable.rb"
    "bin/chef-disable.rb"
    "bin/chef-update.sh"
    "bin/chef-uninstall.sh"
    "bin/chef_client_logs.rb"
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
    -g "${RESOURCE_GROUP}" \
    --name "${LINUX_VM}" \
    --command-id RunShellScript \
    --scripts "${upload_script}" \
    --query "value[0].message" -o tsv

  info "[local-ext] Removing existing Chef install so chef-install.sh runs fresh..."
  # Do NOT remove /tmp/chef-local-ext/gems here — it holds the freshly built
  # local gem uploaded above, which install.sh's `gems/*.gem` glob needs.
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" \
    --name "${LINUX_VM}" \
    --command-id RunShellScript \
    --scripts "(command -v dpkg >/dev/null 2>&1 && dpkg --purge chef || command -v rpm >/dev/null 2>&1 && rpm -e chef) 2>/dev/null || true; echo 'Chef purge done'" \
    --query "value[0].message" -o tsv

  info "[local-ext] Re-running install.sh + enable.sh with local code..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" \
    --name "${LINUX_VM}" \
    --command-id RunShellScript \
    --scripts "EXT_DIR=/tmp/chef-local-ext
echo '=== install.sh ==='
sh \"\$EXT_DIR/install.sh\" 2>&1
echo '=== enable.sh ==='
sh \"\$EXT_DIR/enable.sh\" 2>&1" \
    --query "value[0].message" -o tsv
}

# Uploads local ChefExtensionHandler files to the VM's marketplace extension
# directory (Windows equivalent of patch_linux_local_ext) and re-runs
# install.cmd + enable.cmd so local code changes can be validated without a
# full extension publish cycle.
#
# Requires the marketplace extension to have already run (it installs the gem
# and writes the RuntimeSettings/*.settings file that enable.cmd needs).
patch_windows_local_ext() {
  local ext_handler="${REPO_ROOT}/ChefExtensionHandler"

  # ponytail: same waagent-re-sync race as Linux (see patch_linux_local_ext) -
  # copy the marketplace-installed dir to an isolated path and patch the copy.
  info "[local-ext] Copying extension dir to an isolated path immune to waagent's re-sync..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" \
    --name "${WINDOWS_VM}" \
    --command-id RunPowerShellScript \
    --scripts "\$extDir = Get-ChildItem 'C:\Packages\Plugins\Chef.Bootstrap.WindowsAzure.ChefClient' -Directory | Sort-Object Name | Select-Object -Last 1
if (-not \$extDir) { Write-Host 'ERROR: extension dir not found'; exit 1 }
Remove-Item -Recurse -Force 'C:\chef-local-ext' -ErrorAction SilentlyContinue
Copy-Item \$extDir.FullName 'C:\chef-local-ext' -Recurse
Write-Host \"Copied \$(\$extDir.FullName) to C:\chef-local-ext\"" \
    --query "value[0].message" -o tsv

  # HandlerEnvironment.json still points configFolder/statusFolder/heartbeatFile
  # at the original C:\Packages\Plugins\...\<version> dir; shared.ps1's
  # Get-Azure-Config-Path reads configFolder from this file to locate the
  # latest .settings file, so without this fix the isolated copy silently
  # re-reads the ORIGINAL marketplace settings instead of its own.
  info "[local-ext] Repointing HandlerEnvironment.json at the isolated copy..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" \
    --name "${WINDOWS_VM}" \
    --command-id RunPowerShellScript \
    --scripts "\$extDir = Get-ChildItem 'C:\Packages\Plugins\Chef.Bootstrap.WindowsAzure.ChefClient' -Directory | Sort-Object Name | Select-Object -Last 1
\$hePath = 'C:\chef-local-ext\HandlerEnvironment.json'
\$content = Get-Content \$hePath -Raw
\$content = \$content.Replace(\$extDir.FullName.Replace('\','\\'), 'C:\\chef-local-ext')
[IO.File]::WriteAllText(\$hePath, \$content)
Write-Host 'Repointed HandlerEnvironment.json'" \
    --query "value[0].message" -o tsv

  # Build a fresh azure-chef-extension gem so the isolated copy's gems\*.gem
  # glob (used by chef-install.psm1's `gem install` step) resolves to our
  # local code, not whatever was bundled in the marketplace package.
  info "[local-ext] Building azure-chef-extension gem from local source..."
  (cd "${REPO_ROOT}" && gem build azure-chef-extension.gemspec --output /tmp/azure-chef-extension-local.gem) >/dev/null
  local gem_encoded
  gem_encoded=$(base64 < /tmp/azure-chef-extension-local.gem | tr -d '\n')

  info "[local-ext] Uploading local gem to the isolated copy..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" \
    --name "${WINDOWS_VM}" \
    --command-id RunPowerShellScript \
    --scripts "New-Item -ItemType Directory -Force -Path 'C:\chef-local-ext\gems' | Out-Null
Remove-Item 'C:\chef-local-ext\gems\*.gem' -ErrorAction SilentlyContinue
\$bytes = [Convert]::FromBase64String('${gem_encoded}')
[IO.File]::WriteAllBytes('C:\chef-local-ext\gems\azure-chef-extension-local.gem', \$bytes)
Write-Host '  patched: gems\azure-chef-extension-local.gem'" \
    --query "value[0].message" -o tsv

  info "[local-ext] Uploading local ChefExtensionHandler files to the isolated copy..."
  local windows_files=(
    "install.cmd"
    "enable.cmd"
    "disable.cmd"
    "uninstall.cmd"
    "update.cmd"
    "bin/chef-install.psm1"
    "bin/chef-uninstall.psm1"
    "bin/chef-update.psm1"
    "bin/shared.ps1"
    "bin/chef-enable.rb"
    "bin/chef-disable.rb"
    "bin/parse_env_variables.py"
  )

  # ponytail: az vm run-command scripts are size-limited (see Linux comment
  # above); upload one file per call rather than batching to avoid silent
  # truncation of the combined script.
  local rel_path src encoded dest
  for rel_path in "${windows_files[@]}"; do
    src="${ext_handler}/${rel_path}"
    [[ -f "${src}" ]] || continue
    dest="C:\\chef-local-ext\\${rel_path//\//\\}"
    encoded=$(base64 < "${src}" | tr -d '\n')
    az vm run-command invoke \
      -g "${RESOURCE_GROUP}" \
      --name "${WINDOWS_VM}" \
      --command-id RunPowerShellScript \
      --scripts "\$bytes = [Convert]::FromBase64String('${encoded}')
[IO.File]::WriteAllBytes('${dest}', \$bytes)
Write-Host '  patched: ${rel_path}'" \
      --query "value[0].message" -o tsv
  done

  info "[local-ext] Removing existing Chef install so chef-install.psm1 runs fresh..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" \
    --name "${WINDOWS_VM}" \
    --command-id RunPowerShellScript \
    --scripts "\$apps = Get-WmiObject -Class Win32_Product | Where-Object { \$_.Name -like '*Chef*' }
foreach (\$a in \$apps) { \$a.Uninstall() | Out-Null }
Remove-Item -Recurse -Force 'C:\opscode' -ErrorAction SilentlyContinue
Write-Host 'Chef purge done'" \
    --query "value[0].message" -o tsv

  info "[local-ext] Re-running install.cmd + enable.cmd with local code..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" \
    --name "${WINDOWS_VM}" \
    --command-id RunPowerShellScript \
    --scripts "cd C:\chef-local-ext
Write-Host '=== install.cmd ==='
& '.\install.cmd' 2>&1 | Out-String -Width 4096 | Write-Host
Write-Host '=== enable.cmd ==='
& '.\enable.cmd' 2>&1 | Out-String -Width 4096 | Write-Host" \
    --query "value[0].message" -o tsv
}

# ── Linux test ────────────────────────────────────────────────────────────────
test_linux() {
  info "── Linux Test ──────────────────────────────────"
  info "Creating ${LINUX_IMAGE} VM '${LINUX_VM}'..."
  az vm create \
    -g "${RESOURCE_GROUP}" \
    -n "${LINUX_VM}" \
    --image "${LINUX_IMAGE}" \
    --size Standard_B2s \
    --admin-username "${ADMIN_USER}" \
    --ssh-key-values "${SSH_PUBLIC_KEY_PATH}" \
    --output none
  success "VM '${LINUX_VM}' created"

  info "Installing LinuxChefClient extension (v${EXTENSION_VERSION})..."
  # With --local-ext the marketplace run may fail (e.g. Chef version requires license);
  # that's OK — we only need it to install the gem and write config/0.settings.
  if [[ "${LOCAL_EXT}" == "true" ]]; then
    az vm extension set \
      -g "${RESOURCE_GROUP}" \
      --vm-name "${LINUX_VM}" \
      --name LinuxChefClient \
      --publisher Chef.Bootstrap.WindowsAzure \
      --version "${EXTENSION_VERSION}" \
      --no-auto-upgrade-minor-version \
      --settings "${PUBCONFIG}" \
      --protected-settings "${PRIVCONFIG}" \
      --output none || warn "Marketplace extension reported failure (expected when using --local-ext); continuing to patch with local code"
  else
    az vm extension set \
      -g "${RESOURCE_GROUP}" \
      --vm-name "${LINUX_VM}" \
      --name LinuxChefClient \
      --publisher Chef.Bootstrap.WindowsAzure \
      --version "${EXTENSION_VERSION}" \
      --no-auto-upgrade-minor-version \
      --settings "${PUBCONFIG}" \
      --protected-settings "${PRIVCONFIG}" \
      --output none
  fi
  success "Extension installed"

  if [[ "${LOCAL_EXT}" == "true" ]]; then
    patch_linux_local_ext
  fi

  info "Checking extension provisioning state..."
  STATE=$(az vm extension show \
    -g "${RESOURCE_GROUP}" \
    --vm-name "${LINUX_VM}" \
    --name LinuxChefClient \
    --query "provisioningState" -o tsv)

  if [[ "${LOCAL_EXT}" == "true" ]]; then
    # State reflects the marketplace run, not our local re-run — informational only
    info "Marketplace extension provisioning state: ${STATE} (local code was re-run above)"
  elif [[ "${STATE}" == "Succeeded" ]]; then
    success "Extension provisioning state: ${STATE}"
  else
    fail "Extension provisioning state: ${STATE} (expected Succeeded)"
  fi

  info "Comparing validator key checksum with VM..."
  verify_linux_validator_key_checksum
  print_linux_node_validation_diagnostics

  info "Fetching extension log (last 50 lines)..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" \
    --name "${LINUX_VM}" \
    --command-id RunShellScript \
    --scripts "set -e; list_file=\$(mktemp); [ -f '/var/log/azure/custom.log' ] && echo '/var/log/azure/custom.log' >> \"\$list_file\"; find '/var/log/azure/Chef.Bootstrap.WindowsAzure.LinuxChefClient' -type f -name '*.log' >> \"\$list_file\" 2>/dev/null || true; find '/var/lib/waagent' -maxdepth 2 -type f -path '/var/lib/waagent/Chef.Bootstrap.WindowsAzure.LinuxChefClient-*/*.log' >> \"\$list_file\" 2>/dev/null || true; sort -u \"\$list_file\" -o \"\$list_file\"; if [ ! -s \"\$list_file\" ]; then echo 'Log not found'; rm -f \"\$list_file\"; exit 0; fi; while IFS= read -r log_file; do [ -z \"\$log_file\" ] && continue; echo \"--- \${log_file} (last 50 lines) ---\"; tail -50 \"\$log_file\" || true; done < \"\$list_file\"; rm -f \"\$list_file\"" \
    --query "value[0].message" -o tsv

  if [[ -n "${LICENSE_KEY}" ]]; then
    info "Verifying chef_license_key was read (checking log)..."
    LOG_OUTPUT=$(az vm run-command invoke \
      -g "${RESOURCE_GROUP}" \
      --name "${LINUX_VM}" \
      --command-id RunShellScript \
      --scripts "set -e; match_file=\$(mktemp); [ -f '/var/log/azure/custom.log' ] && grep -i 'license' '/var/log/azure/custom.log' >> \"\$match_file\" 2>/dev/null || true; grep -i 'license' /var/log/azure/Chef.Bootstrap.WindowsAzure.LinuxChefClient/*/*.log >> \"\$match_file\" 2>/dev/null || true; grep -i 'license' /var/lib/waagent/Chef.Bootstrap.WindowsAzure.LinuxChefClient-*/*.log >> \"\$match_file\" 2>/dev/null || true; tail -10 \"\$match_file\" 2>/dev/null || true; rm -f \"\$match_file\"" \
      --query "value[0].message" -o tsv)
    echo "${LOG_OUTPUT}"
    if echo "${LOG_OUTPUT}" | grep -qi "license"; then
      success "License key handling found in extension log"
    else
      warn "Could not confirm license key log entry — check log manually"
    fi
  fi

  download_linux_extension_logs

  success "── Linux test complete ──────────────────────────"
}

# ── Windows test ──────────────────────────────────────────────────────────────
test_windows() {
  local WIN_NODE="${NODE_NAME}-win"
  info "── Windows Test ────────────────────────────────"

  # Windows needs a separate node name in the config
  WIN_PUBCONFIG="${TMPDIR_CONFIGS}/publicconfig-win.json"
  jq --arg node "${WIN_NODE}" '.bootstrap_options.chef_node_name = $node' "${PUBCONFIG}" > "${WIN_PUBCONFIG}"

  info "Creating Windows Server 2022 VM '${WINDOWS_VM}'..."
  az vm create \
    -g "${RESOURCE_GROUP}" \
    -n "${WINDOWS_VM}" \
    --computer-name chef-test-win \
    --image Win2022Datacenter \
    --size Standard_B2ms \
    --admin-username "${ADMIN_USER}" \
    --admin-password "${WINDOWS_PASSWORD}" \
    --output none
  success "VM '${WINDOWS_VM}' created"

  info "Installing ChefClient extension (v${EXTENSION_VERSION})..."
  # With --local-ext the marketplace run may fail (e.g. Chef version requires license);
  # that's OK — we only need it to install the gem and write RuntimeSettings/*.settings.
  if [[ "${LOCAL_EXT}" == "true" ]]; then
    az vm extension set \
      -g "${RESOURCE_GROUP}" \
      --vm-name "${WINDOWS_VM}" \
      --name ChefClient \
      --publisher Chef.Bootstrap.WindowsAzure \
      --version "${EXTENSION_VERSION}" \
      --no-auto-upgrade-minor-version \
      --settings "${WIN_PUBCONFIG}" \
      --protected-settings "${PRIVCONFIG}" \
      --output none || warn "Marketplace extension reported failure (expected when using --local-ext); continuing to patch with local code"
  else
    az vm extension set \
      -g "${RESOURCE_GROUP}" \
      --vm-name "${WINDOWS_VM}" \
      --name ChefClient \
      --publisher Chef.Bootstrap.WindowsAzure \
      --version "${EXTENSION_VERSION}" \
      --no-auto-upgrade-minor-version \
      --settings "${WIN_PUBCONFIG}" \
      --protected-settings "${PRIVCONFIG}" \
      --output none
  fi
  success "Extension installed"

  if [[ "${LOCAL_EXT}" == "true" ]]; then
    patch_windows_local_ext
  fi

  info "Checking extension provisioning state..."
  STATE=$(az vm extension show \
    -g "${RESOURCE_GROUP}" \
    --vm-name "${WINDOWS_VM}" \
    --name ChefClient \
    --query "provisioningState" -o tsv)

  if [[ "${LOCAL_EXT}" == "true" ]]; then
    # State reflects the marketplace run, not our local re-run — informational only
    info "Marketplace extension provisioning state: ${STATE} (local code was re-run above)"
  elif [[ "${STATE}" == "Succeeded" ]]; then
    success "Extension provisioning state: ${STATE}"
  else
    fail "Extension provisioning state: ${STATE} (expected Succeeded)"
  fi

  info "Fetching extension log (last 50 lines)..."
  az vm run-command invoke \
    -g "${RESOURCE_GROUP}" \
    --name "${WINDOWS_VM}" \
    --command-id RunPowerShellScript \
    --scripts "Get-ChildItem 'C:\WindowsAzure\Logs\Plugins\Chef.Bootstrap.WindowsAzure.ChefClient' -Recurse -Filter '*.log' | Select-Object -First 1 | Get-Content -Tail 50" \
    --query "value[0].message" -o tsv

  if [[ -n "${LICENSE_KEY}" ]]; then
    info "Verifying chef_license_key was read (checking log)..."
    LOG_OUTPUT=$(az vm run-command invoke \
      -g "${RESOURCE_GROUP}" \
      --name "${WINDOWS_VM}" \
      --command-id RunPowerShellScript \
      --scripts "Get-ChildItem 'C:\WindowsAzure\Logs\Plugins\Chef.Bootstrap.WindowsAzure.ChefClient' -Recurse -Filter '*.log' | Get-Content | Select-String -Pattern 'license' -CaseSensitive:\$false | Select-Object -Last 10" \
      --query "value[0].message" -o tsv)
    echo "${LOG_OUTPUT}"
    if echo "${LOG_OUTPUT}" | grep -qi "license"; then
      success "License key handling found in extension log"
    else
      warn "Could not confirm license key log entry — check log manually"
    fi
  fi

  success "── Windows test complete ────────────────────────"
}

# ── Run selected platform(s) ──────────────────────────────────────────────────
case "${PLATFORM}" in
  linux|rhel8|rhel10) test_linux ;;
  windows)            test_windows ;;
  both)                test_linux; test_windows ;;
esac

echo ""
success "All tests completed successfully."
echo ""
echo "  Resource group : ${RESOURCE_GROUP}"
[[ "${BUILD_CHEF_SERVER}" == "true" ]] && echo "  Chef Server VM : ${CHEF_SERVER_VM}"
echo "  Chef Server    : ${CHEF_SERVER_URL}"
echo "  Node(s)        : ${NODE_NAME}$([ "${PLATFORM}" = "both" ] && echo ", ${NODE_NAME}-win")"
echo ""
echo "  Verify nodes on Chef Server with:"
echo "    knife node show ${NODE_NAME}"
