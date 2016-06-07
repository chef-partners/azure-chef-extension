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

extract_environment_variables_list() {
  env_vars_list=$(sed ':a;N;$!ba;s/\n//g' $1 | tr -d ' ' | sed 's/.*environment_variables":{\(.*\)}/\1/g' | awk -F\} '{print $1}' | awk '{n=split($0,arr,",");for(i=1;i<=n;i++) print arr[i]}')

  echo $env_vars_list
}

export_env_vars() {
  eval "export $1=$2"
}

read_environment_variables(){
  echo "[$(date)] Reading environment variables"
  config_file_name=$(get_config_settings_file $1)

  if [ -z "$config_file_name" ]; then
    echo "Configuration error. Azure chef extension's config/settings file missing."
    exit 1
  else
    if cat $config_file_name 2>/dev/null | grep -q "environment_variables"; then
      env_vars_list=$(extract_environment_variables_list $config_file_name)

      for i in $env_vars_list
      do
        env_var_name=$(echo $i | awk -F':' '{print $1}')
        env_var_value=$(echo $i | awk -F':' '{OFS=":";$1="";print $0}' | sed 's/^:*//g;s/^ *//g;s/ *$//g')
        export_env_vars $env_var_name $env_var_value
      done
      echo "[$(date)] Environment variables read operation completed"
    else
      echo "[$(date)] No environment variables found"
    fi
  fi
}
