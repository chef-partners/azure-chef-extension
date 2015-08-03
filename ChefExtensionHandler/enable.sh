#!/bin/sh

export PATH=$PATH:/opt/chef/bin:/opt/chef/embedded/bin

SCRIPT=$(readlink -f "$0")

CHEF_EXT_DIR=$(dirname "$SCRIPT")

echo $CHEF_EXT_DIR

update_process_descriptor=/etc/chef/.auto_update_false

if [ -f $auto_update_false ]; then
  echo "[$(date)] Not doing enable, as auto update is false"
  rm $auto_update_false
else
	ruby $CHEF_EXT_DIR/bin/chef-enable.rb
fi
