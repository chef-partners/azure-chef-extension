
#!/bin/sh

. /etc/environment

export PATH=/opt/chef/bin:/opt/chef/embedded/bin:$PATH

SCRIPT=$(readlink -f "$0")

CHEF_EXT_DIR=$(dirname "$SCRIPT")

echo $CHEF_EXT_DIR

ruby $CHEF_EXT_DIR/bin/chef-disable.rb
