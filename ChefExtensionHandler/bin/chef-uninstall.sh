#!/bin/sh

# Function to uninstall ubuntu chef_pkg
uninstall_ubuntu_chef_package(){
  pkg_name=`dpkg -l | grep chef | awk '{print $2}'`
  dpkg_installed="Status: install ok installed"
  install_status=`dpkg -s "$pkg_name" | grep "$dpkg_installed"`

  if test "$install_status" = "$dpkg_installed" ; then
    dpkg -P $pkg_name
    check_uninstallation_status
  else
    echo "No Package found to uninstall!!!"
  fi
}

# Function to Uninstall centOS chef_pkg
uninstall_centos_chef_package(){
  pkg_name=`rpm -qi chef | grep Name | awk '{print $3}'`

  if test "$pkg_name" = "chef" ; then
    rpm -e $pkg_name
    check_uninstallation_status
  else
    echo "No Package found to uninstall!!!"
  fi
}

check_uninstallation_status(){
  if [ $? -eq 0 ]; then
    echo "Package $pkg_name uninstalled successfully."
  else
    echo "Unable to uninstall package Chef."
  fi
}

#function to retrieve the linux distributor
get_linux_distributor(){
  lsb_release -i | awk '{print tolower($3)}'
}

linux_distributor=$(get_linux_distributor)

update_process_descriptor=/etc/chef/.updating_chef_extension

if [ -f $update_process_descriptor ]; then
  echo "Not tried to uninstall, as the update process is running"
  rm $update_process_descriptor
else
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

  case $linux_distributor in 
    "ubuntu")
      uninstall_ubuntu_chef_package
      ;;
    "centos") 
      uninstall_centos_chef_package
      ;;
    *) 
      echo "Unknown Distributor: $linux_distributor"
      exit 1
      ;;
  esac

  # remove /opt/chef if it doesn't get deleted by the uninstallation process
  if [ -d /opt/chef ]; then
    rm -rf /opt/chef

    PREFIX="/usr"
    # ensure symlinks are gone, so that failures to recreate them get caught
    rm -f $PREFIX/bin/chef-client || true
    rm -f $PREFIX/bin/chef-solo || true
    rm -f $PREFIX/bin/chef-apply || true
    rm -f $PREFIX/bin/chef-shell || true
    rm -f $PREFIX/bin/knife || true
    rm -f $PREFIX/bin/shef || true
    rm -f $PREFIX/bin/ohai || true

    echo "Forcibly deleted /opt/chef directory and related symlinks."
  fi
fi