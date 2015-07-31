#!/bin/sh

export PATH=$PATH:/opt/chef/bin:/opt/chef/embedded/bin

SCRIPT=$(readlink -f "$0")

CHEF_EXT_DIR=$(dirname "$SCRIPT")

echo $CHEF_EXT_DIR

update_process_descriptor=/etc/chef/.auto_update_false

if [ -f $auto_update_false ]; then
  echo "[$(date)] Not doing enable, as auto update is false" >> /home/azure/log.txt
 # rm $auto_update_false
else
  echo "Doing enable" >> /home/azure/log.txt
	ruby $CHEF_EXT_DIR/bin/chef-enable.rb
fi
