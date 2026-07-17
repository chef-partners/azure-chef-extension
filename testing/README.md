# E2E Testing

Two test scripts are available:

- **`test-azure-extension.sh`** — standard run-list bootstrap (without policyfile)
- **`test-policyfile.sh`** — policyfile bootstrap (with Chef Server policyfile or local mode)

---

## `test-azure-extension.sh` — Standard (run-list) mode

`test-azure-extension.sh` provisions Azure VMs, installs the Chef extension, and verifies the node bootstraps on Chef Server using a run-list.

### Usage

```bash
bash testing/test-azure-extension.sh \
  --chef-server-url       "https://api.chef.io/organizations/myorg" \
  --validation-client-name "myorg-validator" \
  --validation-pem        ~/.chef/myorg-validator.pem \
  [OPTIONS]
```

Or let the script provision a temporary Chef Server in Azure:

```bash
bash testing/test-azure-extension.sh \
  --build-chef-server \
  [OPTIONS]
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `--chef-server-url` | *(required unless `--build-chef-server`)* | Chef Server URL |
| `--validation-client-name` | *(required unless `--build-chef-server`)* | Validation client name |
| `--validation-pem` | *(required unless `--build-chef-server`)* | Path to the org validator `.pem` |
| `--build-chef-server` | *(false)* | Provision Ubuntu 22.04 Chef Server VM, create org/user, and auto-generate validator PEM |
| `--chef-server-version` | `15.10.84-20251114181706` | Chef Server package version used with `mixlib-install` |
| `--chef-server-vm` | `chef-test-server` | Chef Server VM name used with `--build-chef-server` |
| `--chef-server-org` | `testorg` | Chef organization short name used with `--build-chef-server` |
| `--chef-server-user` | `testadmin` | Chef admin username used with `--build-chef-server` |
| `--azure-tenant` | *(none)* | Azure tenant ID to log into/use |
| `--azure-subscription` | *(none)* | Azure subscription ID or name to select before provisioning |
| `--azure-use-device-code` | *(false)* | Use `az login --use-device-code` (useful when MFA blocks browser login) |
| `--resource-group` | `chef-ext-test-rg` | Azure resource group |
| `--location` | `eastus` | Azure region |
| `--node-name` | `az-ext-test-node` | Chef node name registered on bootstrap |
| `--runlist` | `recipe[base]` | Chef run list |
| `--license-key` | *(none)* | Chef license key — enables licensed download testing |
| `--extension-version` | `1210.14` | Extension version to install |
| `--platform` | `linux` | `linux`, `windows`, or `both` |
| `--skip-cleanup` | *(false)* | Leave Azure resources intact after the test |
| `--ssh-public-key-path` | `~/.ssh/id_rsa.pub` | Public key uploaded to Linux VMs so you can SSH in later |

### Examples

**Linux only (public channel):**
```bash
bash testing/test-azure-extension.sh \
  --chef-server-url "https://api.chef.io/organizations/myorg" \
  --validation-client-name "myorg-validator" \
  --validation-pem ~/.chef/myorg-validator.pem
```

**Both platforms with a license key:**
```bash
bash testing/test-azure-extension.sh \
  --chef-server-url "https://api.chef.io/organizations/myorg" \
  --validation-client-name "myorg-validator" \
  --validation-pem ~/.chef/myorg-validator.pem \
  --license-key "<YOUR_LICENSE_KEY>" \
  --platform both
```

**Provision a temporary Chef Server and test Linux:**
```bash
bash testing/test-azure-extension.sh \
  --build-chef-server \
  --chef-server-version "15.10.84-20251114181706" \
  --platform linux
```

**Tenant-scoped login with MFA (device code):**
```bash
bash testing/test-azure-extension.sh \
  --chef-server-url "https://api.chef.io/organizations/myorg" \
  --validation-client-name "myorg-validator" \
  --validation-pem ~/.chef/myorg-validator.pem \
  --azure-tenant "a2b2d6bc-afe1-4696-9c37-f97a7ac416d7" \
  --azure-use-device-code \
  --azure-subscription "<subscription-id-or-name>"
```

### What the script does

1. Runs `validation/validate-linux.sh` for a local sanity check
2. Builds `publicconfig.json` / `privateconfig.json` from your inputs (including `chef_license_key` if `--license-key` is set)
3. Creates an Azure resource group
4. If `--build-chef-server` is set, provisions an Ubuntu VM, installs Chef Server with `mixlib-install`, and creates a test org/user/validator key
5. Provisions a Ubuntu 22.04 VM (Linux) and/or Windows Server 2022 VM (Windows); Linux VMs get your SSH public key uploaded
6. Installs the `LinuxChefClient` / `ChefClient` extension
7. Asserts `provisioningState == Succeeded`
8. Dumps the last 50 lines of the extension log
9. If `--license-key` was set, checks the log confirms the key was read
10. Deletes the resource group on exit (unless `--skip-cleanup`)

---

## `test-policyfile.sh` — Policyfile mode

`test-policyfile.sh` validates the extension in policyfile mode. Two sub-modes are supported:

| Mode | What it tests |
|------|---------------|
| `server` | `policy_name` + `policy_group` in `bootstrap_options`; policy is pushed to a Chef Server; no validation key required |
| `local` | `local_mode: true` in `bootstrap_options`; `chef-client --local-mode`; no Chef Server; Policyfile.lock.json pre-staged on the VM |
| `both` | Runs server mode then local mode sequentially (two VMs) |

### Usage

**Chef Server policyfile mode (push a policy, then bootstrap):**
```bash
bash testing/test-policyfile.sh \
  --mode server \
  --chef-server-url "https://api.chef.io/organizations/myorg" \
  --user-pem ~/.chef/myuser.pem \
  --policy-name "base" \
  --policy-group "production"
```

**Local mode (no Chef Server):**
```bash
bash testing/test-policyfile.sh \
  --mode local \
  --policy-name "base" \
  --policy-group "production" \
  --policyfile-lock ~/chef-repo/Policyfile.lock.json
```

**Build a temporary Chef Server and test both modes:**
```bash
bash testing/test-policyfile.sh \
  --mode both \
  --build-chef-server
```

### Key options

| Option | Default | Description |
|--------|---------|-------------|
| `--mode` | `server` | `server`, `local`, or `both` |
| `--policy-name` | `azure-test-policy` | Policyfile name |
| `--policy-group` | `test-group` | Policy group to assign the node to |
| `--policyfile-lock` | *(generated stub)* | Path to an existing `Policyfile.lock.json`. If omitted, a minimal stub with an empty run_list is generated — sufficient to exercise the code path without cookbooks. |
| `--policy-document-path` | `/etc/chef/Policyfile.lock.json` | Path on the VM where the lock file is pre-staged (local mode only) |
| `--chef-server-url` | *(required for server mode)* | Chef Server URL |
| `--validation-pem` | *(optional in policyfile mode)* | Org validator PEM. Omit to test validator-less policyfile bootstrap. |
| `--user-pem` | *(required for server mode push)* | Chef user `.pem` used to push the policy to the Chef Server |
| `--build-chef-server` | *(false)* | Provision a temporary Chef Server VM |
| `--local-ext` | *(false)* | Upload local `ChefExtensionHandler` files and re-run install/enable (test local code changes) |

All other options (`--resource-group`, `--location`, `--extension-version`, `--license-key`, etc.) match `test-azure-extension.sh`.

### What the script verifies

For both modes:
- Extension provisioning state (Succeeded)
- `client.rb` contains `policy_name` and `policy_group`
- `client.rb` does **not** contain `validation_key` or `validation_client_name`
- `first-boot.json` does **not** contain `target_runlist`
- `node-registered` flag and `client.pem` are present

Additionally for server mode:
- `chef_server_url` is present in `client.rb`

Additionally for local mode:
- `chef_server_url` is absent from `client.rb`
- Extension logs reference `--local-mode`

### Prerequisites

- `az` CLI, `jq`, `python3` (same as `test-azure-extension.sh`)
- **Server mode**: Chef Workstation (`chef push`) or `knife` on the test runner to push the policy. If neither is available, the script falls back to the Chef Server Policies API via `python3 -c "import requests"`.
- **Local mode**: No extra tools — the Policyfile.lock.json is base64-encoded and written to the VM via `az vm run-command` before the extension installs.
