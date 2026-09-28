#!/bin/sh
# Minimal self-check for protectedSettings-based chef_license_key handling
# (ChefExtensionHandler/bin/shared.sh): asserts the license key is preferred
# from decrypted protectedSettings, and that reading it from the deprecated
# public settings location still works but emits a warning.
#
# Usage: sh spec/shell_specs/protected_settings_spec.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/../../ChefExtensionHandler/bin/shared.sh"

FAILED=0
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# Point at a throwaway "waagent" cert dir instead of the real /var/lib/waagent.
LINUX_CERT_PATH="$WORK_DIR"
THUMBPRINT="ABCDEF1234567890"

openssl req -x509 -newkey rsa:2048 -keyout "$WORK_DIR/${THUMBPRINT}.prv" \
  -out "$WORK_DIR/${THUMBPRINT}.crt" -days 1 -nodes \
  -subj "/CN=protected-settings-test" >/dev/null 2>&1

PROTECTED_JSON='{"chef_license_key":"protected-license-abc"}'
ENCRYPTED=$(printf '%s' "$PROTECTED_JSON" | \
  openssl smime -encrypt -aes256 -outform DER -binary "$WORK_DIR/${THUMBPRINT}.crt" | base64 | tr -d '\n')

CONFIG_DIR="$WORK_DIR/config"
mkdir -p "$CONFIG_DIR"
SETTINGS_FILE="$CONFIG_DIR/0.settings"
cat > "$SETTINGS_FILE" <<EOF
{"runtimeSettings":[{"handlerSettings":{"protectedSettingsCertThumbprint":"${THUMBPRINT}","protectedSettings":"${ENCRYPTED}","publicSettings":{"chef_license_key":"public-license-xyz"}}}]}
EOF

result=$(get_value_from_protected_settings "$SETTINGS_FILE" "chef_license_key")
if [ "$result" = "protected-license-abc" ]; then
  echo "[PASS] reads chef_license_key from decrypted protectedSettings"
else
  echo "[FAIL] expected protected-license-abc, got: ${result}"
  FAILED=1
fi

CHEF_LICENSE_KEY=""
output="$(read_chef_license_key "$WORK_DIR" 2>&1 1>/dev/null)"
case "$output" in
  *"DEPRECATED"*) echo "[FAIL] unexpected deprecation warning when protectedSettings has the key: ${output}"; FAILED=1 ;;
  *) echo "[PASS] no deprecation warning when protectedSettings has the key" ;;
esac
read_chef_license_key "$WORK_DIR" >/dev/null 2>&1
if [ "$CHEF_LICENSE_KEY" = "protected-license-abc" ]; then
  echo "[PASS] CHEF_LICENSE_KEY set from protectedSettings"
else
  echo "[FAIL] expected CHEF_LICENSE_KEY=protected-license-abc, got: ${CHEF_LICENSE_KEY}"
  FAILED=1
fi

# Now remove protectedSettings entirely and confirm the deprecated
# public-settings fallback still works, with a warning.
cat > "$SETTINGS_FILE" <<EOF
{"runtimeSettings":[{"handlerSettings":{"publicSettings":{"chef_license_key":"public-license-xyz"}}}]}
EOF

CHEF_LICENSE_KEY=""
output="$(read_chef_license_key "$WORK_DIR" 2>&1 1>/dev/null)"
case "$output" in
  *"DEPRECATED"*) echo "[PASS] warns when falling back to public settings" ;;
  *) echo "[FAIL] expected deprecation warning, got: ${output}"; FAILED=1 ;;
esac
read_chef_license_key "$WORK_DIR" >/dev/null 2>&1
if [ "$CHEF_LICENSE_KEY" = "public-license-xyz" ]; then
  echo "[PASS] CHEF_LICENSE_KEY set from deprecated public settings fallback"
else
  echo "[FAIL] expected CHEF_LICENSE_KEY=public-license-xyz, got: ${CHEF_LICENSE_KEY}"
  FAILED=1
fi

exit "$FAILED"
