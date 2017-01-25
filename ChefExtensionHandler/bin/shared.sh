#!/bin/sh

get_linux_distributor(){
#### Using python -mplatform command to get distributor name #####
  if python -mplatform | grep centos > /dev/null; then
    linux_distributor='centos'
  elif python -mplatform | grep Ubuntu > /dev/null; then
    linux_distributor='ubuntu'
  elif python -mplatform | grep debian > /dev/null; then
    linux_distributor='debian'
  elif python -mplatform | grep redhat > /dev/null; then
    linux_distributor='rhel'
  fi
  echo "${linux_distributor}"
}

get_config_settings_file() {
  config_files_path="$1/config/*.settings"
  config_file_name=`ls $config_files_path 2>/dev/null | sort -V | tail -1`

  echo $config_file_name
}

get_file_path_to_parse_env_variables(){
  path_to_parse_env_variables="$1/bin/parse_env_variables.py"
  echo $path_to_parse_env_variables
}

export_env_vars() {
  commands="`python $path_to_parse_env_variables \"$1\"`"
  eval $commands
}

read_environment_variables(){
  echo "[$(date)] Reading environment variables"
  config_file_name=$(get_config_settings_file $1)
  path_to_parse_env_variables=$(get_file_path_to_parse_env_variables $1)

  if [ -z "$config_file_name" ]; then
    echo "Configuration error. Azure chef extension's config/settings file missing."
    exit 1
  else
    if cat $config_file_name 2>/dev/null | grep -q "environment_variables"; then
      export_env_vars $config_file_name
      echo "[$(date)] Environment variables read operation completed"
      echo "`env`"
    else
      echo "[$(date)] No environment variables found"
    fi
  fi
}
