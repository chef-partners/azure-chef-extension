#!/bin/sh

get_linux_distributor(){
#### Determine distributor from /etc/os-release ID/ID_LIKE. Python is only a
#### fallback for images without os-release: python -mplatform stopped naming
#### the distro in Python >= 3.8, which made it return nothing on RHEL >= 9.
  linux_distributor=''
  os_release_file="${CHEF_OS_RELEASE_FILE:-/etc/os-release}"
  if [ -r "$os_release_file" ]; then
    os_release_id=`. "$os_release_file" 2>/dev/null; echo "$ID"`
    os_release_id_like=`. "$os_release_file" 2>/dev/null; echo "$ID_LIKE"`
    # ID is authoritative; ID_LIKE words are consulted in order for derivatives
    # (e.g. rocky/alma report ID_LIKE="rhel centos fedora").
    for os_release_candidate in "$os_release_id" $os_release_id_like; do
      case "$os_release_candidate" in
        ubuntu)
          linux_distributor='ubuntu'; break;;
        debian)
          linux_distributor='debian'; break;;
        centos)
          linux_distributor='centos'; break;;
        rhel)
          linux_distributor='rhel'; break;;
        ol|oracle)
          linux_distributor='linuxoracle'; break;;
      esac
    done
  fi
  if [ -z "$linux_distributor" ]; then
    if (command -v python3) > /dev/null; then
      python_command='python3'
    else
      python_command='python'
    fi
    if ( $python_command -mplatform || /usr/libexec/platform-python -mplatform ) 2>/dev/null | grep centos > /dev/null; then
      linux_distributor='centos'
    elif ( $python_command -mplatform ) 2>/dev/null | grep Ubuntu > /dev/null; then
      linux_distributor='ubuntu'
    elif ( $python_command -mplatform ) 2>/dev/null | grep debian > /dev/null; then
      linux_distributor='debian'
    elif ( $python_command -mplatform || /usr/libexec/platform-python -mplatform ) 2>/dev/null | grep redhat > /dev/null; then
      linux_distributor='rhel'
    elif ( $python_command -mplatform || /usr/libexec/platform-python -mplatform ) 2>/dev/null | grep -E -i "linux.*oracle" > /dev/null; then
      linux_distributor='linuxoracle'
    fi
  fi
  echo "${linux_distributor}"
}

# install_file TYPE FILENAME
# TYPE is "rpm", "deb", "solaris", "sh", etc.
install_file() {
  package_name=$2
  echo "Installing package $package_name"
  package_type=$1
  case "$package_type" in
    "rpm")
      if test "x$platform" = "xnexus" || test "x$platform" = "xios_xr"; then
        echo "installing with yum..."
        yum install -yv "$package_name"
      else
        echo "installing with rpm..."
        rpm -Uvh --oldpackage --replacepkgs "$package_name"
      fi
      ;;
    "deb")
      echo "installing with dpkg..."
      dpkg -i "$package_name"
      ;;
    "bff")
      echo "installing with installp..."
      installp -aXYgd "$package_name" all
      ;;
    "solaris")
      echo "installing with pkgadd..."
      echo "conflict=nocheck" > $tmp_dir/nocheck
      echo "action=nocheck" >> $tmp_dir/nocheck
      echo "mail=" >> $tmp_dir/nocheck
      pkgrm -a $tmp_dir/nocheck -n $project >/dev/null 2>&1 || true
      pkgadd -G -n -d "$package_name" -a $tmp_dir/nocheck $project
      ;;
    "pkg")
      echo "installing with installer..."
      cd / && /usr/sbin/installer -pkg "$package_name" -target /
      ;;
    "dmg")
      echo "installing dmg file..."
      hdiutil detach "/Volumes/chef_software" >/dev/null 2>&1 || true
      hdiutil attach "$package_name" -mountpoint "/Volumes/chef_software"
      cd / && /usr/sbin/installer -pkg `find "/Volumes/chef_software" -name \*.pkg` -target /
      hdiutil detach "/Volumes/chef_software"
      ;;
    "sh" )
      echo "installing with sh..."
      sh "$package_name"
      ;;
    "p5p" )
      echo "installing p5p package..."
      pkg install -g "$package_name" $project
      ;;
    *)
      echo "Unknown filetype: $package_type"
      report_bug
      exit 1
      ;;
  esac
  package_install_state=$?
  if test $package_install_state -ne 0; then
    echo "Installation failed"
    report_bug
    exit 1
  fi
}

get_config_settings_file() {
  config_file_path=$1
  config_files_path="$config_file_path/config/*.settings"
  config_file_name=`ls $config_files_path 2>/dev/null | sort -V | tail -1`

  echo $config_file_name
}

# Get values from 0.settings file
get_value_from_setting_file() {
  chef_value=""
  if cat $1 2>/dev/null | grep -q $2; then
    chef_value=`sed ':a;N;$!ba;s/\n//g' $1 | sed 's/.*'"${2}"'" *: *" *\(.*\)/\1/' 2>/dev/null | awk -F\" '{ print $1 }' | sed 's/[ \t]*$//'`
  fi
  echo $chef_value
}

# Get file path of parse_env_variables.py file
get_file_path_to_parse_env_variables(){
  chef_extension_directory_path=$1
  path_to_parse_env_variables="$chef_extension_directory_path/bin/parse_env_variables.py"
  echo $path_to_parse_env_variables
}

# Execute parse_env_variables.py file to fetch values of `environment_variables` from 0.setting files
export_env_vars() {
  config_file_name=$1
  if ( command -v python3) > /dev/null;then
    commands="`python3 $path_to_parse_env_variables \"$config_file_name\"`"
  else
    commands="`python $path_to_parse_env_variables \"$config_file_name\"`"
  fi
  # $commands will echo the key values under `environment_variables` which will be eval later
  # eg : eval export abc="xyz";
  eval $commands
}

# Read chef_license_key from settings and export CHEF_LICENSE_KEY
read_chef_license_key(){
  chef_extension_directory_path=$1
  config_file_name=$(get_config_settings_file $chef_extension_directory_path)
  chef_license_key_value=$(get_value_from_setting_file $config_file_name "chef_license_key" &)
  if [ ! -z "$chef_license_key_value" ]; then
    eval "export CHEF_LICENSE_KEY=$chef_license_key_value;"
    echo "Set CHEF_LICENSE_KEY environment variable from chef_license_key setting"
  fi
}

# Read chef_license_bypass from settings and export CHEF_LICENSE_BYPASS.
# When "true", allows installation to proceed without a chef_license_key
# (falling back to the deprecated omnitruck download).
read_chef_license_bypass(){
  chef_extension_directory_path=$1
  config_file_name=$(get_config_settings_file $chef_extension_directory_path)
  chef_license_bypass_value=$(get_value_from_setting_file $config_file_name "chef_license_bypass" &)
  if [ "$chef_license_bypass_value" = "true" ]; then
    export CHEF_LICENSE_BYPASS="true"
    echo "Set CHEF_LICENSE_BYPASS environment variable from chef_license_bypass setting"
  fi
}

# Warn when requesting a Chef Infra Client version older than 18 without a
# license key — those versions require license_id to download from packages.chef.io.
warn_if_legacy_version_needs_license(){
  chef_version=$1
  [ -z "$chef_version" ] && return
  major_version=$(echo "$chef_version" | cut -d. -f1)
  if [ "$major_version" -lt 18 ] 2>/dev/null && [ -z "$CHEF_LICENSE_KEY" ]; then
    echo "WARNING: chef_version=${chef_version}: Chef Infra Client versions < 18 require a valid license key to download from packages.chef.io."
    echo "WARNING: Set chef_license_key in extension settings (free trial keys are accepted)."
  fi
}

# Require a license key unless the caller explicitly opted into the
# unlicensed/omnitruck fallback via the chef_license_bypass setting.
log_license_key_status(){
  if [ -z "$CHEF_LICENSE_KEY" ]; then
    if [ "$CHEF_LICENSE_BYPASS" != "true" ]; then
      echo "[$(date)] ERROR: No chef_license_key provided. Set chef_license_key in extension settings, or set chef_license_bypass to \"true\" to explicitly opt into the deprecated, unlicensed omnitruck download path." >&2
      exit 1
    fi
    echo "[$(date)] WARNING: No chef_license_key provided; chef_license_bypass is set. Omnitruck is being shut down — unlicensed downloads will stop working in the near future." >&2
    echo "[$(date)] Falling back to omnitruck download (DEPRECATED — will stop working when omnitruck is shut down)"
  else
    echo "[$(date)] CHEF_LICENSE_KEY is set from chef_license_key; licensed download will be attempted"
  fi
}

# To set environment variable to new shell
read_environment_variables(){
  chef_extension_directory_path=$1
  echo "[$(date)] Reading environment variables"
  config_file_name=$(get_config_settings_file $chef_extension_directory_path)
  path_to_parse_env_variables=$(get_file_path_to_parse_env_variables $chef_extension_directory_path)

  echo "Reading chef licence value from settings file"
  chef_licence_value=$(get_value_from_setting_file $config_file_name "CHEF_LICENSE" &)

  if [ -z "$config_file_name" ]; then
    echo "Configuration error. Azure chef extension's config/settings file missing."
    exit 1
  else
    if [ ! -z "$chef_licence_value" ]; then
      eval "export CHEF_LICENSE=$chef_licence_value;"
      echo "Set CHEF_LICENSE Environment variable as $CHEF_LICENSE"
    fi
    if cat $config_file_name 2>/dev/null | grep -q "environment_variables"; then
      export_env_vars $config_file_name
      echo "[$(date)] Environment variables read operation completed"
      echo "`env`"
    else
      echo "[$(date)] No environment variables found"
    fi
  fi
}
