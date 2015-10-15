#!/bin/sh

# returns script dir
get_script_dir(){
  SCRIPT=$(readlink -f "$0")
  script_dir=`dirname $SCRIPT`
  echo "${script_dir}"
}

chef_extension_root=$(get_script_dir)/../

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
		if [ "$1" == "centos" ]; then
    	yum install -d0 -e0 -y curl
		else
			apt-get install -q -y curl
		fi
  fi
}

install_from_repo_centos(){
	platform="centos"
  curl_check $platform
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

install_from_repo_ubuntu() {
	platform="ubuntu"
	curl_check $platform

	# Need to first run apt-get update so that apt-transport-https can be installed
	echo -n "Running apt-get update... "
	apt-get update
	echo "done."

	echo -n "Installing apt-transport-https... "
	apt-get install -y apt-transport-https
	echo "done."

	apt_config_url="https://packagecloud.io/install/repositories/chef/stable/config_file.list?os=ubuntu&dist=trusty&source=script"
	apt_source_path="/etc/apt/sources.list.d/chef_stable.list"

	echo -n "Installing $apt_source_path..."

	# create an apt config file for this repository
	curl -sSf "${apt_config_url}" > $apt_source_path
	curl_exit_code=$?

	if [ "$curl_exit_code" = "22" ]; then
  	echo -n "Unable to download repo config from: "
	  echo "${apt_config_url}"
	  echo
	  echo "Please contact support@packagecloud.io and report this."
	  [ -e $apt_source_path ] && rm $apt_source_path
  	exit 1
	elif [ "$curl_exit_code" = "35" ]; then
  	echo "curl is unable to connect to packagecloud.io over TLS when running: "
	  echo "    curl ${apt_config_url}"
	  echo "This is usually due to one of two things:"
	  echo
	  echo " 1.) Missing CA root certificates (make sure the ca-certificates package is installed)"
  	echo " 2.) An old version of libssl. Try upgrading libssl on your system to a more recent version"
	  echo
  	echo "Contact support@packagecloud.io with information about your system for help."
	  [ -e $apt_source_path ] && rm $apt_source_path
  	exit 1
	elif [ "$curl_exit_code" -gt "0" ]; then
  	echo
	  echo "Unable to run: "
  	echo "    curl ${apt_config_url}"
	  echo
  	echo "Double check your curl installation and try again."
	  [ -e $apt_source_path ] && rm $apt_source_path
  	exit 1
	else
  	echo "done."
	fi

	echo -n "Importing packagecloud gpg key... "
	# import the gpg key
	curl https://packagecloud.io/gpg.key | sudo apt-key add -
	echo "done."

	echo -n "Running apt-get update... "
	# update apt on this system
	apt-get update
	echo "done."

  echo "Installing chef-client package"
	apt-get install chef
	echo "Package Installed successfully ..."
}

get_linux_distributor(){
#### Using python -mplatform command to get distributor name #####
  if python -mplatform | grep centos > /dev/null; then
    linux_distributor='centos'
  elif python -mplatform | grep Ubuntu > /dev/null; then
    linux_distributor='ubuntu'
  fi
  echo "${linux_distributor}"
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
      install_from_repo_ubuntu
      ;;
    "centos")
      echo "Linux Distributor: ${linux_distributor}"
      install_from_repo_centos
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
