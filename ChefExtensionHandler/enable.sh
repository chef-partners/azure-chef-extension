#!/bin/sh

export PATH=$PATH:/opt/chef/bin:/opt/chef/embedded/bin

SCRIPT=$(readlink -f "$0")

CHEF_EXT_DIR=$(dirname "$SCRIPT")

echo $CHEF_EXT_DIR

ruby $CHEF_EXT_DIR/bin/chef-enable.rb
