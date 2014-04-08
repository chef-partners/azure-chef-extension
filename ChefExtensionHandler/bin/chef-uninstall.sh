#!/bin/sh

# Uninstall the custom gem
export PATH=$PATH:/opt/chef/embedded/bin:/opt/chef/bin
azure_chef_extn_gem=`gem list azure-chef-extension | grep azure-chef-extension | awk '{print $1}'`

if test "$azure_chef_extn_gem" = "azure-chef-extension" ; then
  echo "Removing azure-chef-extension gem."
  gem uninstall azure-chef-extension
  if [ $? -ne 0 ]; then
    echo "Unable to uninstall gem azure-chef-extension."
  fi
else
  echo "Gem azure-chef-extension is not installed !!!" 
fi

# Uninstall chef_pkg
pkg_name=`dpkg -l | grep chef | awk '{print $2}'`
dpkg_installed="Status: install ok installed"
install_status=`dpkg -s "$pkg_name" | grep "$dpkg_installed"`

if test "$install_status" = "$dpkg_installed" ; then
  dpkg -P $pkg_name
  if [ $? -eq 0 ]; then
    echo "Package $pkg_name uninstalled successfully."
  else
    echo "Unable to uninstall package Chef."
  fi
else
  echo "No Package found to uninstall!!!"
fi