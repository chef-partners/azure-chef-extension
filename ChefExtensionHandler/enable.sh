#!/bin/sh

export PATH=$PATH:/opt/chef/bin:/opt/chef/embedded/bin

SCRIPT=$(readlink -f "$0")

CHEF_EXT_DIR=$(dirname "$SCRIPT")

echo $CHEF_EXT_DIR

update_process_descriptor=/etc/chef/.updating_chef_extension

if [ -f $update_process_descriptor ]; then
  echo "[$(date)] Not doing enable, as the update process is running"
  rm $update_process_descriptor
else
	ruby $CHEF_EXT_DIR/bin/chef-enable.rb
fi
