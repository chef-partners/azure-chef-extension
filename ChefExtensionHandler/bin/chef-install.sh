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

get_hostname (){
  echo "Getting the hostname of this machine..."

  host=`hostname -f 2>/dev/null`
  if [ "$host" = "" ]; then
    host=`hostname 2>/dev/null`
    if [ "$host" = "" ]; then
      host=$HOSTNAME
    fi
  fi

  if [ "$host" = "" ]; then
    echo "Unable to determine the hostname of your system!"
    echo
    echo "Please consult the documentation for your system. The files you need "
    echo "to modify to do this vary between Linux distribution and version."
    echo
    exit 1
  fi

  echo "Found hostname: ${host}"
}

curl_check (){
  echo "Checking for curl..."
  if command -v curl > /dev/null; then
    echo "Detected curl..."
  else
    echo "Installing curl..."
    yum install -d0 -e0 -y curl
  fi
}

install_from_local_package(){
  # install chef
  chef_client_installer=$(get_deb_installer)
  installer_type="deb"
  install_file $installer_type "$chef_client_installer"
}

install_from_repo(){
  curl_check
  get_hostname
  yum_repo_path=/etc/yum.repos.d/chef_stable.repo
  yum_repo_config_url="https://packagecloud.io/install/repositories/chef/stable/config_file.repo?os=el&dist=5&name=${host}"

  echo "Downloading repository file: ${yum_repo_config_url}"
  curl -f "${yum_repo_config_url}" > $yum_repo_path
  curl_exit_code=$?

  if [ "$curl_exit_code" = "22" ]; then
    echo
    echo -n "Unable to download repo config from: "
    echo "${yum_repo_config_url}"
    echo
    echo "Please contact support@packagecloud.io and report this."
    [ -e $yum_repo_path ] && rm $yum_repo_path
    exit 1
  elif [ "$curl_exit_code" = "35" ]; then
    echo
    echo "curl is unable to connect to packagecloud.io over TLS when running: "
    echo "curl ${yum_repo_config_url}"
    echo
    echo "This is usually due to one of two things:"
    echo
    echo " 1.) Missing CA root certificates (make sure the ca-certificates package is installed)"
    echo " 2.) An old version of libssl. Try upgrading libssl on your system to a more recent version"
    echo
    echo "Contact support@packagecloud.io with information about your system for help."
    [ -e $yum_repo_path ] && rm $yum_repo_path
    exit 1
  elif [ "$curl_exit_code" -gt "0" ]; then
    echo
    echo "Unable to run: "
    echo "curl ${yum_repo_config_url}"
    echo
    echo "Double check your curl installation and try again."
    [ -e $yum_repo_path ] && rm $yum_repo_path
    exit 1
  else
    echo "done."
  fi

  yum -y install chef
  echo "Package Installed successfully ..."
}

 
get_linux_distributor(){
#### for centos if lsb_release package not available calling yum install #####  
  if ! command -v lsb_release > /dev/null; then
    if python -mplatform | grep centos > /dev/null; then
      yum install -d0 -e0 -y redhat-lsb-core
    fi
  fi
  lsb_release -i | awk '{print tolower($3)}'
}

########### Script starts from here ##################
echo "Call for Checking linux distributor"
linux_distributor=$(get_linux_distributor)
auto_update_false=/etc/chef/.auto_update_false

if [ -f $auto_update_false ]; then
  echo "[$(date)] Not doing install, as auto update is false"
else
  echo "After linux distributor check .... "
  # get chef installer
  case $linux_distributor in
    "ubuntu")
      echo "Linux Distributor: ${linux_distributor}"
      install_from_local_package
      ;;
    "centos")
      echo "Linux Distributor: ${linux_distributor}"
      install_from_repo
      ;;
    *)
      echo "No Linux Distributor detected ... exiting..."
      exit 1
      ;;
  esac

  export PATH=$PATH:/opt/chef/bin/:/opt/chef/embedded/bin

  # install azure chef extension gem
  install_chef_extension_gem "$chef_extension_root/gems/*.gem"
fi
