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

# delete .updating_chef_extension file if it exists
update_process_descriptor=/etc/chef/.updating_chef_extension
if [ -f $update_process_descriptor ]; then
  rm $update_process_descriptor
fi

commands_script_path=$(get_script_dir)
echo "Command script path: $commands_script_path" >> /home/azure/log.txt

chef_ext_dir=`dirname $commands_script_path`
echo "Chef_ext_dir: $chef_ext_dir" >> /home/azure/log.txt

# this gets auto_update_client value from previous extension version
waagentdir="$(dirname "$chef_ext_dir")"
echo "waagentdir: $waagentdir" >> /home/azure/log.txt
previous_extension=`ls "$waagentdir" | grep Chef.Bootstrap.WindowsAzure.LinuxChefClient- | tail -2 | head -1`
echo "previous_extension: $previous_extension" >> /home/azure/log.txt
previous_extension="$waagentdir/$previous_extension"
echo "previous_extension: $previous_extension" >> /home/azure/log.txt
handler_settings_file=`ls $previous_extension/config/*.settings -S -r | head -1`
echo "handler_settings_file: $handler_settings_file" >> /home/azure/log.txt

auto_update_client=`ruby -e "require 'chef/azure/helpers/parse_json';value_from_json_file_for_ps '$handler_settings_file','runtimeSettings','0','handlerSettings','publicSettings','autoUpdateClient'"`
echo "auto_update_client: $auto_update_client" >> /home/azure/log.txt
if [ "$auto_update_client" != "true" ]
then
  echo "Auto update disabled"
  # touch the update_process_descriptor
  # We refer this file inside uninstall.sh, install.sh and enable.sh so that waagent doesn't update
  # even if autoUpdateClient=false.
  # Waagent itself spawns processes for uninstall, install and enable otherwise.
  touch /etc/chef/.updating_chef_extension
  echo "Called before return........" >> /home/azure/log.txt
  return
fi

echo "Didn't go inside if-then block" >> /home/azure/log.txt

BACKUP_FOLDER="etc_chef_extn_update_`date +%s`"

# this use to know uninstall is called from update
called_from_update="update"

# Save chef configuration.
mv /etc/chef /tmp/$BACKUP_FOLDER

# uninstall chef.
sh $commands_script_path/chef-uninstall.sh "$called_from_update"

# Restore Chef Configuration
mv /tmp/$BACKUP_FOLDER /etc/chef

# install new version of chef extension
sh $commands_script_path/chef-install.sh

# touch the update_process_descriptor
touch /etc/chef/.updating_chef_extension
