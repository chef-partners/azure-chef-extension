#!/bin/sh

export PATH=/opt/chef/bin:/opt/chef/embedded/bin:$PATH

gem unpack knife --target /opt/chef/knife

SCRIPT=$(readlink -f "$0")

CHEF_EXT_DIR=$(dirname "$SCRIPT")

echo $CHEF_EXT_DIR

. $CHEF_EXT_DIR/bin/shared.sh

read_environment_variables $CHEF_EXT_DIR

ruby $CHEF_EXT_DIR/bin/chef-enable.rb
