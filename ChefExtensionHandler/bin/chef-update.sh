#!/bin/sh
# Reinstall with new version
#
# GA will do this:
# 1 unpack new pkg at <extn>/<new ver>/new zip
# 2 disable old version
# 3 update new version
# 4 uninstall old version
# 5 enable new version

# returns script dir
get_script_dir(){
  SCRIPT=$(readlink -f "$0")
  script_dir=`dirname $SCRIPT`
  echo "${script_dir}"
}

commands_script_path=$(get_script_dir)

chef_ext_dir=`dirname $commands_script_path`
handler_settings_file=`ls $chef_ext_dir/config/*.settings -S -r | head -1`

auto_update=`ruby -e "require 'chef/azure/helpers/parse_json';value_from_json_file_for_ps '$handler_settings_file','runtimeSettings','0','handlerSettings','autoUpdate'"`

if [ $auto_update = "false" ]
then
  echo "Auto update disabled"
  return
fi

BACKUP_FOLDER="etc_chef_extn_update_`date +%s`"

# Save chef configuration.
mv /etc/chef /tmp/$BACKUP_FOLDER

# uninstall chef.
sh $commands_script_path/chef-uninstall.sh

# Restore Chef Configuration
mv /tmp/$BACKUP_FOLDER /etc/chef

# install new version of chef extension
sh $commands_script_path/chef-install.sh

# touch the update_process_descriptor
touch /etc/chef/.updating_chef_extension