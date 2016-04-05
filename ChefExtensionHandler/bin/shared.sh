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

