#!/bin/sh
# Unit test for get_linux_distributor (ChefExtensionHandler/bin/shared.sh).
# Self-contained: needs only sh + coreutils. Run: sh spec/shell_specs/get_linux_distributor_test.sh
# Uses CHEF_OS_RELEASE_FILE to point the function at fixture files, and a stub
# python3 on PATH to exercise the legacy fallback deterministically.

script_dir=$(dirname "$0")
. "$script_dir/../../ChefExtensionHandler/bin/shared.sh"

tmp_dir="${TMPDIR:-/tmp}/gld_test_$$"
mkdir -p "$tmp_dir/bin"
trap 'rm -rf "$tmp_dir"' EXIT

failures=0
assert_distributor() {
  expected=$1
  actual=$(get_linux_distributor)
  if [ "$actual" = "$expected" ]; then
    echo "ok   - $test_name -> [$actual]"
  else
    echo "FAIL - $test_name -> expected [$expected], got [$actual]"
    failures=$((failures + 1))
  fi
}

fixture() {
  printf '%s\n' "$@" > "$tmp_dir/os-release"
  export CHEF_OS_RELEASE_FILE="$tmp_dir/os-release"
}

test_name="RHEL 9"
fixture 'NAME="Red Hat Enterprise Linux"' 'ID="rhel"' 'ID_LIKE="fedora"' 'VERSION_ID="9.8"'
assert_distributor rhel

test_name="RHEL 10 (ID beats ID_LIKE centos)"
fixture 'NAME="Red Hat Enterprise Linux"' 'ID="rhel"' 'ID_LIKE="centos fedora"' 'VERSION_ID="10.2"'
assert_distributor rhel

test_name="RHEL 8"
fixture 'ID="rhel"' 'ID_LIKE="fedora"' 'VERSION_ID="8.10"'
assert_distributor rhel

test_name="CentOS Stream 9"
fixture 'ID="centos"' 'ID_LIKE="rhel fedora"' 'VERSION_ID="9"'
assert_distributor centos

test_name="Rocky 9 (via ID_LIKE)"
fixture 'ID="rocky"' 'ID_LIKE="rhel centos fedora"' 'VERSION_ID="9.4"'
assert_distributor rhel

test_name="Oracle Linux 9"
fixture 'ID="ol"' 'ID_LIKE="fedora"' 'VERSION_ID="9.4"'
assert_distributor linuxoracle

test_name="Ubuntu 22.04"
fixture 'NAME="Ubuntu"' 'ID=ubuntu' 'ID_LIKE=debian' 'VERSION_ID="22.04"'
assert_distributor ubuntu

test_name="Debian 12"
fixture 'ID=debian' 'VERSION_ID="12"'
assert_distributor debian

test_name="unsupported distro (sles) -> empty"
fixture 'ID="sles"' 'ID_LIKE="suse"' 'VERSION_ID="15.5"'
assert_distributor ''

# Legacy fallback: no os-release, python reports the distro (pre-3.8 behavior)
cat > "$tmp_dir/bin/python3" <<'EOF'
#!/bin/sh
echo "Linux-3.10.0-1160.el7.x86_64-x86_64-with-redhat-7.9-Maipo"
EOF
chmod +x "$tmp_dir/bin/python3"
export CHEF_OS_RELEASE_FILE="$tmp_dir/does-not-exist"
PATH="$tmp_dir/bin:$PATH"

test_name="no os-release, python3 reports redhat (RHEL 7 era)"
assert_distributor rhel

test_name="no os-release, python3 reports only glibc (modern python) -> empty"
cat > "$tmp_dir/bin/python3" <<'EOF'
#!/bin/sh
echo "Linux-5.14.0-1.x86_64-x86_64-with-glibc2.34"
EOF
assert_distributor ''

unset CHEF_OS_RELEASE_FILE
if [ "$failures" -eq 0 ]; then
  echo "all tests passed"
else
  echo "$failures test(s) FAILED"
  exit 1
fi
