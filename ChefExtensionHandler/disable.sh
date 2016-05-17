
#!/bin/sh

. /etc/environment
echo '*************** output for disable.sh*******************************' >> /tmp/temp1.log
export >> /tmp/temp1.log
echo '*******************end****************************' >> /tmp/temp1.log
export PATH=/opt/chef/bin:/opt/chef/embedded/bin:$PATH

SCRIPT=$(readlink -f "$0")

CHEF_EXT_DIR=$(dirname "$SCRIPT")

echo $CHEF_EXT_DIR

ruby $CHEF_EXT_DIR/bin/chef-disable.rb
