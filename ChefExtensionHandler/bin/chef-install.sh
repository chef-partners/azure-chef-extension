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

curl_check(){
  echo "Checking for curl..."
  if command -v curl > /dev/null; then
    echo "Detected curl..."
  else
    echo "Installing curl..."
    if [ "$1" = "centos" -o "$1" = "rhel" ]; then
      yum install -d0 -e0 -y curl
    else
      apt-get install -q -y curl
    fi
  fi
}

curl_status(){
  if [ "$1" = "22" ]; then
    echo
    echo -n "Unable to download repo config from: "
    echo "${2}"
    echo
    echo "Please contact support@packagecloud.io and report this."
    [ -e $3 ] && rm $3
    exit 1
  elif [ "$1" = "35" ]; then
    echo
    echo "curl is unable to connect to packagecloud.io over TLS when running: "
    echo "curl ${2}"
    echo
    echo "This is usually due to one of two things:"
    echo
    echo " 1.) Missing CA root certificates (make sure the ca-certificates package is installed)"
    echo " 2.) An old version of libssl. Try upgrading libssl on your system to a more recent version"
    echo
    echo "Contact support@packagecloud.io with information about your system for help."
    [ -e $3 ] && rm $3
    exit 1
  elif [ "$1" -gt "0" ]; then
    echo
    echo "Unable to run: "
    echo "curl ${2}"
    echo
    echo "Double check your curl installation and try again."
    [ -e $3 ] && rm $3
    exit 1
  else
    echo "done."
  fi
}

get_config_settings_file() {
  config_files_path="$chef_extension_root/config/*.settings"
  config_file_name=`ls $config_files_path 2>/dev/null | sort -V | tail -1`

  echo $config_file_name
}

get_chef_version() {
  config_file_name=$(get_config_settings_file)
  if [ -z "$config_file_name" ]; then
    echo "No config file found !!"
  else
    if cat $config_file_name 2>/dev/null | grep -q "bootstrap_version"; then
      chef_version=`sed ':a;N;$!ba;s/\n//g' $config_file_name | sed 's/.*bootstrap_version" *: *" *\(.*\)/\1/' 2>/dev/null | awk -F\" '{ print $1 }' | sed 's/[ \t]*$//'`
      echo $chef_version
    else
      echo ""
    fi
  fi
}

get_chef_package_from_omnitruck() {
  echo "Call for Checking linux distributor"
  platform=$(get_linux_distributor)

  #check if chef-client is already installed
  if [ "$platform" = "ubuntu" -o "$platform" = "debian" ]; then
    dpkg-query -s chef
  elif [ "$platform" = "centos" -o "$platform" = "rhel" ]; then
    yum list installed | grep -w "chef"
  fi

  if [ $? -ne 0 ]; then
    echo "Starting installation process:"
    date +"%T"
    curl_check $platform

    # Starting forked subshell to read chef-client version from runtimesettings file
    echo "Reading chef-client version from settings file"
    chef_version=$(get_chef_version &)
    ARCH=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
    if [ $ARCH -eq "64" ]; then
      ARCH="x86_64"
    elif [ $ARCH -eq "32" ]; then
       ARCH="i686"
    fi

    if [ $platform = "centos" ]; then
      platform_version=`sed -r 's/.* ([0-9]).*/\1/' /etc/centos-release`
      p="el"
    elif [ $platform = "debian" ]; then
      platform_version=$(cat /etc/debian_version)
      p=$platform
    elif [ $platform = "rhel" ]; then
      platform_version=`sed -r 's/.* ([0-9]).*/\1/' /etc/redhat-release`
      p="el"
    else
      platform_version=$(lsb_release -sr)
      p=$platform
    fi

    # temp directory to keep installed chef package
    temp_dir=`mktemp -d`

    echo "Installing chef-client package"
    if [ "$chef_version" = "No config file found !!" ]; then
      echo "Configuration error. Azure chef extension Settings file missing."
      exit 1
    elif [ -z "$chef_version" ]; then
      curl -L -o "$temp_dir/chef" "http://www.chef.io/chef/download?p=$p&pv=$platform_version&m=$ARCH"
    else
      curl -L -o "$temp_dir/chef" "http://www.chef.io/chef/download?p=$p&pv=$platform_version&m=$ARCH&v=$chef_version"
    fi

    install_chef $temp_dir $platform
    check_installation_status

    #delete temp_dir
    rm -rf $temp_dir

    echo "End of installation:"
    date +"%T"
  fi
}

install_chef(){
  if [ "$2" = "ubuntu" -o "$2" = "debian" ]; then
    dpkg -i "$1/chef"
  elif [ "$2" = "centos" -o "$2" = "rhel" ]; then
    rpm -ivh "$1/chef"
  fi
}

check_installation_status(){
  if [ $? -eq 0 ]; then
    echo "[$(date)] Package Chef installed successfully."
  else
    echo "[$(date)] Unable to uninstall package Chef."
  fi
}

########### Script starts from here ##################
auto_update_false=/etc/chef/.auto_update_false

if [ -f $auto_update_false ]; then
  echo "[$(date)] Not doing install, as auto update is false"
else
  echo "export test_1='123'" >> /etc/environment
  echo "export test_2='456'" >> /etc/environment
  . /etc/environment
  export

  get_chef_package_from_omnitruck
  export PATH=/opt/chef/bin/:/opt/chef/embedded/bin:$PATH

  # check if azure-chef-extension is installed
  azure_chef_extn_gem=`gem list azure-chef-extension | grep azure-chef-extension | awk '{print $1}'`

  if test "$azure_chef_extn_gem" = "azure-chef-extension" ; then
    echo "azure-chef-extension is already installed."
  else
    # install azure chef extension gem
    install_chef_extension_gem "$chef_extension_root/gems/*.gem"
  fi
fi
