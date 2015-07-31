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
echo "[$(date)] ***inside update.sh update started PATH:: $PATH" >> /home/azure/log.txt
# delete .updating_chef_extension file if it exists
auto_update_false=/etc/chef/.auto_update_false
echo "[$(date)] ***inside update.sh bfr if auto_update_false:: $auto_update_false" >> /home/azure/log.txt
if [ -f $auto_update_false ]; then
  echo "auto_update_false exists" >> /home/azure/log.txt
  rm $auto_update_false
fi
echo "[$(date)] ***inside update.sh afr if update_process_descriptor:: $update_process_descriptor" >> /home/azure/log.txt
commands_script_path=$(get_script_dir)
echo "[$(date)] ***inside update.sh Command script path: $commands_script_path" >> /home/azure/log.txt

chef_ext_dir=`dirname $commands_script_path`
echo "[$(date)] ***inside update.sh Chef_ext_dir: $chef_ext_dir" >> /home/azure/log.txt

# this gets auto_update_client value from previous extension version
waagentdir="$(dirname "$chef_ext_dir")"
echo "[$(date)] ***inside update.sh waagentdir: $waagentdir" >> /home/azure/log.txt
previous_extension=`ls "$waagentdir" | grep Chef.Bootstrap.WindowsAzure.LinuxChefClient- | tail -2 | head -1`
echo "[$(date)] ***inside update.sh previous_extension: $previous_extension" >> /home/azure/log.txt
previous_extension="$waagentdir/$previous_extension"
echo "[$(date)] ***inside update.sh previous_extension: $previous_extension" >> /home/azure/log.txt
handler_settings_file=`ls $previous_extension/config/*.settings -S -r | head -1`
echo "[$(date)] ***inside update.sh handler_settings_file: $handler_settings_file" >> /home/azure/log.txt

auto_update_client=`ruby -e "require 'chef/azure/helpers/parse_json';value_from_json_file_for_ps '$handler_settings_file','runtimeSettings','0','handlerSettings','publicSettings','autoUpdateClient'"`
echo "[$(date)] ***inside update.sh bfr if auto_update_client: $auto_update_client" >> /home/azure/log.txt
if [ "$auto_update_client" != "true" ]
then
  echo "[$(date)] ***inside update.sh Auto update disabled" >> /home/azure/log.txt
  # touch the update_process_descriptor
  # We refer this file inside uninstall.sh, install.sh and enable.sh so that waagent doesn't update
  # even if autoUpdateClient=false.
  # Waagent itself spawns processes for uninstall, install and enable otherwise.
  ERR=$(touch /etc/chef/.auto_update_false 2>&1 > /dev/null)
  #touch /etc/chef/.updating_chef_extension

  echo "[$(date)] ***inside update.sh ERR ::: $ERR Called before return........" >> /home/azure/log.txt
  return
fi
echo "[$(date)] ***inside update.sh afr if auto_update_client: $auto_update_client" >> /home/azure/log.txt

BACKUP_FOLDER="etc_chef_extn_update_`date +%s`"

echo "[$(date)] ***inside update.sh BACKUP_FOLDER: $BACKUP_FOLDER" >> /home/azure/log.txt
# this use to know uninstall is called from update
called_from_update="update"

echo "[$(date)] ***inside update.sh called_from_update: $called_from_update" >> /home/azure/log.txt

# Save chef configuration.
mv /etc/chef /tmp/$BACKUP_FOLDER
echo "[$(date)] ***inside update.sh mv /etc/chef and bfr chef-uninstall.sh " >> /home/azure/log.txt
# uninstall chef.
sh $commands_script_path/chef-uninstall.sh "$called_from_update"
echo "[$(date)] ***inside update.sh aftr chef-uninstall.sh " >> /home/azure/log.txt
# Restore Chef Configuration
mv /tmp/$BACKUP_FOLDER /etc/chef
echo "[$(date)] ***inside update.sh aftr restoring chef config" >> /home/azure/log.txt

# install new version of chef extension
sh $commands_script_path/chef-install.sh
echo "[$(date)] ***inside update.sh aftr chef-uninstall.sh " >> /home/azure/log.txt

# touch the update_process_descriptor
#touch /etc/chef/.updating_chef_extension

