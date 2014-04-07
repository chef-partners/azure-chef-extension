#!/bin/sh

SCRIPT=$(readlink -f "$0")

CHEF_EXT_DIR=$(dirname "$SCRIPT")

echo $CHEF_EXT_DIR

sudo sh $CHEF_EXT_DIR/bin/chef-uninstall.sh
