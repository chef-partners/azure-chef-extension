#!/bin/sh

SCRIPT=$(readlink -f "$0")

CHEF_EXT_DIR=$(dirname "$SCRIPT")

echo $CHEF_EXT_DIR >> /var/log/azure/custom.log

echo "***** inside install.sh bfr sudo sh chef-install.sh call" >> /var/log/azure/custom.log
$CHEF_EXT_DIR/bin/chef-install.sh >> /var/log/azure/custom.log
echo "***** inside install.sh aftr sudo sh chef-install.sh call" >> /var/log/azure/custom.log