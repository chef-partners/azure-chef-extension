#!/bin/sh

. /etc/environment
echo '*************** output for enable.sh*******************************' >> /tmp/temp1.log
export >> /tmp/temp1.log
echo '*******************end****************************' >> /tmp/temp1.log

export PATH=/opt/chef/bin:/opt/chef/embedded/bin:$PATH

SCRIPT=$(readlink -f "$0")

CHEF_EXT_DIR=$(dirname "$SCRIPT")

echo $CHEF_EXT_DIR

auto_update_false=/etc/chef/.auto_update_false

if [ -f $auto_update_false ]; then
  echo "[$(date)] Not doing enable, as auto update is false"
  rm $auto_update_false
else
	ruby $CHEF_EXT_DIR/bin/chef-enable.rb
fi
