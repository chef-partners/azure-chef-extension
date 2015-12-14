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
export PATH=$PATH:/opt/chef/bin/:/opt/chef/embedded/bin

get_script_dir(){
  SCRIPT=$(readlink -f "$0")
  script_dir=`dirname $SCRIPT`
  echo "${script_dir}"
}

# delete .auto_update_false file if it exists
auto_update_false=/etc/chef/.auto_update_false
if [ -f $auto_update_false ]; then
  rm $auto_update_false
fi
commands_script_path=$(get_script_dir)

chef_ext_dir=`dirname $commands_script_path`

# this gets auto_update_client value from previous extension version
waagentdir="$(dirname "$chef_ext_dir")"
previous_extension=`ls "$waagentdir" | grep Chef.Bootstrap.WindowsAzure.LinuxChefClient- | tail -2 | head -1`
previous_extension="$waagentdir/$previous_extension"
handler_settings_file=`ls $previous_extension/config/*.settings -S -r | head -1`

auto_update_client=`ruby -e "require 'chef/azure/helpers/parse_json';value_from_json_file_for_ps '$handler_settings_file','runtimeSettings','0','handlerSettings','publicSettings','autoUpdateClient'"`
if [ "$auto_update_client" != "true" ]
then
  # touch the auto_update_false
  # We refer this file inside uninstall.sh, install.sh and enable.sh so that waagent doesn't update
  # even if autoUpdateClient=false.
  # Waagent itself spawns processes for uninstall, install and enable otherwise.
  touch /etc/chef/.auto_update_false
  return
fi

BACKUP_FOLDER="etc_chef_extn_update_`date +%s`"

# this use to know uninstall is called from update
called_from_update="update"

# Save chef configuration.
mv /etc/chef /tmp/$BACKUP_FOLDER
# uninstall chef.
uninstall_chef_client=`ruby -e "require 'chef/azure/helpers/parse_json';value_from_json_file_for_ps '$handler_settings_file','runtimeSettings','0','handlerSettings','publicSettings','uninstallChefClient'"`
if [ "$uninstall_chef_client" = "true" ]; then
  sh $commands_script_path/chef-uninstall.sh "$called_from_update"
fi
# Restore Chef Configuration
mv /tmp/$BACKUP_FOLDER /etc/chef

# install new version of chef extension
sh $commands_script_path/chef-install.sh

# touch the update_process_descriptor
touch /etc/chef/.updating_chef_extension

