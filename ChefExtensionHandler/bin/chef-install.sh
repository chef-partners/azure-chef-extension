#!/bin/sh

# returns script dir
get_script_dir(){
  SCRIPT=$(readlink -f "$0")
  script_dir=`dirname $SCRIPT`
  echo "${script_dir}"
}

chef_extension_root=$(get_script_dir)/../

# returns chef-client bebian installer
get_deb_installer(){
  pkg_file="$chef_extension_root/installer/chef-client-latest.deb"
  echo "${pkg_file}"
}

get_rpm_installer(){
  pkg_file="$chef_extension_root/installer/chef-client-latest.rpm"
  echo "${pkg_file}"
}

# install_file TYPE FILENAME
# TYPE is "deb"
install_file() {
  echo "Installing Chef $version"
  case "$1" in
    "deb")
      echo "[$(date)] Installing with dpkg...$2"
      dpkg -i "$2"
      ;;
    "rpm")
      echo "[$(date)] Installing with rpm...$2"
      rpm -i "$2"
      ;;
    *)
      echo "Unknown filetype: $1"
      exit 1
      ;;
  esac
  if test $? -ne 0; then
    echo "[$(date)] Chef Client installation failed"
    exit 1
  else
    echo "[$(date)] Chef Client Package installation succeeded!"
  fi
}

# install azure chef extension gem
install_chef_extension_gem(){
 echo "[$(date)] Installing Azure Chef Extension gem"
 gem install "$1" --no-ri --no-rdoc

  if test $? -ne 0; then
    echo "[$(date)] Azure Chef Extension gem installation failed"
    exit 1
  else
    echo "[$(date)] Azure Chef Extension gem installation succeeded"
  fi
}

get_linux_distributor(){
  lsb_release -i | awk '{print tolower($3)}'
}


########### Script starts from here ##################
linux_distributor=$(get_linux_distributor)

auto_update_false=/etc/chef/.auto_update_false

if [ -f $auto_update_false ]; then
  echo "[$(date)] Not doing install, as auto update is false" >> /home/azure/log.txt
else
  echo "Doing install" >> /home/azure/log.txt
  # get chef installer
  case $linux_distributor in
    "ubuntu")
      echo "[$(date)] ***inside install.sh Linux Distributor" >> /home/azure/log.txt
      chef_client_installer=$(get_deb_installer)
      echo "[$(date)] ***inside install.sh chef_client_installer: $chef_client_installer" >> /home/azure/log.txt
      installer_type="deb"
      ;;
    "centos")
      echo "[$(date)] ***inside install.sh centos Distributor" >> /home/azure/log.txt
      chef_client_installer=$(get_rpm_installer)
      echo "[$(date)] ***inside install.sh chef_client_installer: $chef_client_installer" >> /home/azure/log.txt
      installer_type="rpm"
      ;;
    *)
      echo "Unknown Distributor: $linux_distributor" >> /home/azure/log.txt
      exit 1
      ;;
  esac

  # install chef
  install_file $installer_type "$chef_client_installer"
  echo "[$(date)] ***inside install.sh installer_type: $installer_type" >> /home/azure/log.txt

  export PATH=$PATH:/opt/chef/bin/:/opt/chef/embedded/bin

  # install azure chef extension gem
  install_chef_extension_gem "$chef_extension_root/gems/*.gem"
  echo "[$(date)] ***inside install.sh after installing chef extension gem" >> /home/azure/log.txt
fi

