#!/bin/sh

get_config_settings_file() {
  config_files_path="$1/config/*.settings"
  config_file_name=`ls $config_files_path 2>/dev/null | sort -V | tail -1`

  echo $config_file_name
}

get_uninstall_chef_client_flag() {
  if [ -z "$1" ]; then
    echo "false"
  else
    export PATH=/opt/chef/bin/:/opt/chef/embedded/bin:$PATH
    uninstall_chef_client_flag=`ruby -e "require 'chef/azure/helpers/parse_json';value_from_json_file_for_ps '$1','runtimeSettings','0','handlerSettings','publicSettings','uninstallChefClient'"`
    echo $uninstall_chef_client_flag
  fi
}

SCRIPT=$(readlink -f "$0")

CHEF_EXT_DIR=$(dirname "$SCRIPT")

echo $CHEF_EXT_DIR >> /var/log/azure/custom.log

config_file_name=$(get_config_settings_file $CHEF_EXT_DIR)
uninstall_chef_client=$(get_uninstall_chef_client_flag $config_file_name)

if [ "$uninstall_chef_client" = "true" ]; then
  $CHEF_EXT_DIR/bin/chef-uninstall.sh >> /var/log/azure/custom.log
fi