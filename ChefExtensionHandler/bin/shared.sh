#!/bin/sh

get_linux_distributor(){
#### Using python -mplatform command to get distributor name #####
  if ( python -mplatform || /usr/libexec/platform-python -mplatform ) | grep centos > /dev/null; then
    linux_distributor='centos'
  elif ( python -mplatform || /usr/libexec/platform-python -mplatform ) | grep Ubuntu > /dev/null; then
    linux_distributor='ubuntu'
  elif ( python -mplatform || /usr/libexec/platform-python -mplatform ) | grep debian > /dev/null; then
    linux_distributor='debian'
  elif ( python -mplatform || /usr/libexec/platform-python -mplatform ) | grep redhat > /dev/null; then
    linux_distributor='rhel'
  elif ( python -mplatform || /usr/libexec/platform-python -mplatform ) | grep -E -i "linux.*oracle" > /dev/null; then
    linux_distributor='linuxoracle'
  fi
  echo "${linux_distributor}"
}

# install_file TYPE FILENAME
# TYPE is "rpm", "deb", "solaris", "sh", etc.
install_file() {
  echo "Installing package $2"
  case "$1" in
    "rpm")
      if test "x$platform" = "xnexus" || test "x$platform" = "xios_xr"; then
        echo "installing with yum..."
        yum install -yv "$2"
      else
        echo "installing with rpm..."
        rpm -Uvh --oldpackage --replacepkgs "$2"
      fi
      ;;
    "deb")
      echo "installing with dpkg..."
      dpkg -i "$2"
      ;;
    "bff")
      echo "installing with installp..."
      installp -aXYgd "$2" all
      ;;
    "solaris")
      echo "installing with pkgadd..."
      echo "conflict=nocheck" > $tmp_dir/nocheck
      echo "action=nocheck" >> $tmp_dir/nocheck
      echo "mail=" >> $tmp_dir/nocheck
      pkgrm -a $tmp_dir/nocheck -n $project >/dev/null 2>&1 || true
      pkgadd -G -n -d "$2" -a $tmp_dir/nocheck $project
      ;;
    "pkg")
      echo "installing with installer..."
      cd / && /usr/sbin/installer -pkg "$2" -target /
      ;;
    "dmg")
      echo "installing dmg file..."
      hdiutil detach "/Volumes/chef_software" >/dev/null 2>&1 || true
      hdiutil attach "$2" -mountpoint "/Volumes/chef_software"
      cd / && /usr/sbin/installer -pkg `find "/Volumes/chef_software" -name \*.pkg` -target /
      hdiutil detach "/Volumes/chef_software"
      ;;
    "sh" )
      echo "installing with sh..."
      sh "$2"
      ;;
    "p5p" )
      echo "installing p5p package..."
      pkg install -g "$2" $project
      ;;
    *)
      echo "Unknown filetype: $1"
      report_bug
      exit 1
      ;;
  esac
  if test $? -ne 0; then
    echo "Installation failed"
    report_bug
    exit 1
  fi
}

get_config_settings_file() {
  config_files_path="$1/config/*.settings"
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
  path_to_parse_env_variables="$1/bin/parse_env_variables.py"
  echo $path_to_parse_env_variables
}

# Execute parse_env_variables.py file to fetch values of `environment_variables` from 0.setting files
export_env_vars() {
  if ( python -mplatform || /usr/libexec/platform-python -mplatform ) | grep "redhat-8" > /dev/null; then
    commands="`/usr/libexec/platform-python $path_to_parse_env_variables \"$1\"`"
  else
    commands="`python $path_to_parse_env_variables \"$1\"`"
  fi
  # $commands will echo the key values under `environment_variables` which will be eval later
  # eg : eval export abc="xyz";
  eval $commands
}

# To set environment variable to new shell
read_environment_variables(){
  echo "[$(date)] Reading environment variables"
  config_file_name=$(get_config_settings_file $1)
  path_to_parse_env_variables=$(get_file_path_to_parse_env_variables $1)

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
