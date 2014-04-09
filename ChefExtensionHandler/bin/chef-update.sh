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

# Save chef configuration.
mv /etc/chef /tmp

# uninstall chef.
sh $commands_script_path/chef-uninstall.sh

# Restore Chef Configuration
mv /tmp/chef /etc

# install new version of chef extension
sh $commands_script_path/chef-install.sh

# touch the update_process_descriptor
touch /etc/chef/.update_process_descriptor