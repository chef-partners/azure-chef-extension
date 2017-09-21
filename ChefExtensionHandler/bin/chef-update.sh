#!/bin/sh
# Reinstall with new version
#
# GA will do this:
# 1 disable old version
# 2 update new version
# 3 uninstall old version
# 4 install new version
# 5 enable new version

# returns script dir
export PATH=/opt/chef/bin/:/opt/chef/embedded/bin:$PATH

get_script_dir(){
  SCRIPT=$(readlink -f "$0")
  script_dir=`dirname $SCRIPT`
  echo "${script_dir}"
}

commands_script_path=$(get_script_dir)

. $commands_script_path/shared.sh

chef_ext_dir=`dirname $commands_script_path`

read_environment_variables $chef_ext_dir

# delete node-registered file if it exists
node_registered=/etc/chef/node-registered
if [ -f $node_registered ]; then
  rm $node_registered
fi

# uninstall chef extension.
sh $commands_script_path/chef-uninstall.sh

# install new version of chef extension
sh $commands_script_path/chef-install.sh

# touch the update_process_descriptor
touch /etc/chef/.updating_chef_extension
