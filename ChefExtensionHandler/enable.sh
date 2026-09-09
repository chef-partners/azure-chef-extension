#!/bin/sh

export PATH=/opt/chef/bin:/opt/chef/embedded/bin:$PATH

# chef-ice (Habitat) fallback: ruby and the chef gem live under /hab/pkgs/...,
# not /opt/chef, so the omnibus PATH above never finds them.
if ! command -v ruby >/dev/null 2>&1; then
  _hab_ruby_bin=$(dirname "$(ls /hab/pkgs/core/ruby*/*/*/bin/ruby 2>/dev/null | sort -V | tail -1)")
  [ -n "$_hab_ruby_bin" ] && export PATH="$_hab_ruby_bin:$PATH"
  _hab_chef_vendor=$(dirname "$(ls /hab/pkgs/chef/chef-infra-client/*/*/bin/chef-client 2>/dev/null | sort -V | tail -1)")/../vendor
  [ -d "$_hab_chef_vendor" ] && export GEM_PATH="$_hab_chef_vendor:$GEM_PATH"
fi

SCRIPT=$(readlink -f "$0")

CHEF_EXT_DIR=$(dirname "$SCRIPT")

echo $CHEF_EXT_DIR

. $CHEF_EXT_DIR/bin/shared.sh

read_environment_variables $CHEF_EXT_DIR

ruby $CHEF_EXT_DIR/bin/chef-enable.rb
