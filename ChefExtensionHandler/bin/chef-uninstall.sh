# Author:: Prabhu Das (<prabhu.das@clogeny.com>)
# Copyright:: Copyright (c) 2014 Opscode, Inc.

# uninstall chef
# Actions:
#    - uninstall chef

# Uninstall the custom gem
export PATH=$PATH:/opt/chef/embedded/bin
azure_chef_extn_gem=`gem list azure-chef-extension | grep azure-chef-extension | awk '{print $1}'`
if test "$azure_chef_extn_gem" = "azure-chef-extension" ; then
  echo "Started removing gem azure-chef-extension"
  uninstall_gem=`gem uninstall azure-chef-extension`
  if [ $? -eq 0 ]; then
    echo "Gem $azure_chef_extn_gem_status uninstalled successfully."
  else
    echo "Unable to uninstall gem azure-chef-extension."
  fi
else
  echo "Gem azure-chef-extension not found !!!" 
fi

# Uninstall chef_pkg
install_status=`dpkg -l | grep chef | awk '{print $1}'`
pkg_name=`dpkg -l | grep chef | awk '{print $2}'`
if test "$install_status" = "ii" ; then
  echo "Started removing Chef."
  uninstall=`sudo dpkg -P $pkg_name`
  if [ $? -eq 0 ]; then
    echo "Package $pkg_name uninstalled successfully."
  else
    echo "Unable to uninstall package Chef."
  fi
else
  echo "No Package found to uninstall!!!"
fi

