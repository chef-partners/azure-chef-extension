
#!/bin/sh

SCRIPT=$(readlink -f "$0")

CHEF_EXT_DIR=$(dirname "$SCRIPT")

echo $CHEF_EXT_DIR

ruby $CHEF_EXT_DIR/bin/chef-enable.rb