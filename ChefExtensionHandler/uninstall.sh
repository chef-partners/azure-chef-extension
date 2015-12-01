#!/bin/sh

SCRIPT=$(readlink -f "$0")

CHEF_EXT_DIR=$(dirname "$SCRIPT")

echo $CHEF_EXT_DIR >> /var/log/azure/custom.log

uninstall_chef_client="false"

if [ "$uninstall_chef_client" = "true" ]; then
  $CHEF_EXT_DIR/bin/chef-uninstall.sh >> /var/log/azure/custom.log
fi