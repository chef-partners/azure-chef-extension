#!/bin/sh
# returns script dir
get_script_dir(){
  SCRIPT=$(readlink -f "$0")
  script_dir=`dirname $SCRIPT`
  echo "${script_dir}"
}

commands_script_path=$(get_script_dir)

. $commands_script_path/shared.sh

chef_extension_root=$commands_script_path/../

read_environment_variables $chef_extension_root

#funtions to delete ubuntu chef configuration files i.e. /etc/chef
remove_chef_config(){
  if [ ! -z $delete_chef_config ] && [ $delete_chef_config = "true" ] ; then
    echo "Deleteing chef configurations directory /etc/chef."
    rm -rf /etc/chef || true
  fi
}

# Function to uninstall ubuntu chef_pkg
uninstall_ubuntu_or_debian_chef_package(){
  pkg_name=`dpkg -l | grep chef | awk '{print $2}'`
  echo "[$(date)] Uninstalling package $pkg_name ..."
  apt-get remove --purge $pkg_name -y
  check_uninstallation_status
}

# Function to Uninstall centOS or RHEL chef_pkg
uninstall_centos_or_rhel_chef_package(){
  pkg_name=`rpm -qi chef | grep Name | awk '{print $3}'`
  if test "$pkg_name" = "chef" ; then
    echo "[$(date)] Uninstalling package $pkg_name ..."
    yum remove $pkg_name -y
    check_uninstallation_status
  else
    echo "[$(date)] No Package found to uninstall!!!"
  fi
}

check_uninstallation_status(){
  if [ $? -eq 0 ]; then
    echo "[$(date)] Package $pkg_name uninstalled successfully."
  else
    echo "[$(date)] Unable to uninstall package Chef."
  fi
}

########### Script starts from here ###################
linux_distributor=$(get_linux_distributor)

auto_update_false=/etc/chef/.auto_update_false

export PATH=/opt/chef/embedded/bin:/opt/chef/bin:$PATH

if [ -f $auto_update_false ]; then
  uninstall_chef_client=`ruby -e "require 'chef/azure/helpers/parse_json';value_from_json_file_for_ps '$handler_settings_file','runtimeSettings','0','handlerSettings','publicSettings','uninstallChefClient'"`
  if [ "$uninstall_chef_client" = "true" ]; then
    echo "Invalid config specified...uninstallChefClient flag cannot be true when autoUpdateClient flag is false." >> /var/log/azure/custom.log
  fi
  exit 1
fi

update_process_descriptor=/etc/chef/.updating_chef_extension

called_from_update=$1

if [ -f $update_process_descriptor ]; then
  echo "[$(date)] Not doing uninstall, as the update process is running"
  rm $update_process_descriptor
else

  chef_ext_dir=`dirname $commands_script_path`

  if [ "$called_from_update" = "update" ]; then
    waagentdir="$(dirname "$chef_ext_dir")"
    previous_extension=`ls "$waagentdir" | grep Chef.Bootstrap.WindowsAzure.LinuxChefClient- | tail -2 | head -1`
    previous_extension="$waagentdir/$previous_extension"
    handler_settings_file=`ls $previous_extension/config/*.settings -S -r | head -1`
  else
    handler_settings_file=`ls $chef_ext_dir/config/*.settings -S -r | head -1`
  fi

  # Reading deleteChefConfig value from settings file
  delete_chef_config=`ruby -e "require 'chef/azure/helpers/parse_json';value_from_json_file_for_ps '$handler_settings_file','runtimeSettings','0','handlerSettings','publicSettings','deleteChefConfig'"`

  # Uninstall the custom gem
  azure_chef_extn_gem=`gem list azure-chef-extension | grep azure-chef-extension | awk '{print $1}'`

  if test "$azure_chef_extn_gem" = "azure-chef-extension" ; then
    echo "[$(date)] Removing azure-chef-extension gem."
    gem uninstall azure-chef-extension
    if [ $? -ne 0 ]; then
      echo "[$(date)] Unable to uninstall gem azure-chef-extension."
    else
      echo "[$(date)] Uninstalled azure-chef-extension gem successfully."
    fi
  else
    echo "[$(date)] Gem azure-chef-extension is not installed !!!"
  fi

  case $linux_distributor in
    "ubuntu"|"debian")
      echo "Linux Distributor: ${linux_distributor}"
      remove_chef_config
      uninstall_ubuntu_or_debian_chef_package
      ;;
    "centos"|"rhel")
      echo "Linux Distributor: ${linux_distributor}"
      remove_chef_config
      uninstall_centos_or_rhel_chef_package
      ;;
    *)
      echo "Unknown Distributor: $linux_distributor"
      exit 1
      ;;
  esac

  # remove /opt/chef if it doesn't get deleted by the uninstallation process
  if [ -d /opt/chef ]; then
    rm -rf /opt/chef
    echo "Forcibly deleted /opt/chef directory."
  fi

  PREFIX="/usr"
  # ensure symlinks are gone, so that failures to recreate them get caught
  rm -f $PREFIX/bin/chef-client || true
  rm -f $PREFIX/bin/chef-solo || true
  rm -f $PREFIX/bin/chef-apply || true
  rm -f $PREFIX/bin/chef-shell || true
  rm -f $PREFIX/bin/knife || true
  rm -f $PREFIX/bin/shef || true
  rm -f $PREFIX/bin/ohai || true

  echo "Deleted related symlinks."
fi
