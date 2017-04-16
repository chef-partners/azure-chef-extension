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

########### Script starts from here ###################

export PATH=/opt/chef/embedded/bin:/opt/chef/bin:$PATH

update_process_descriptor=/etc/chef/.updating_chef_extension

delete_node(){
  `ruby -e "require 'chef/azure/helpers/shared'; include ChefAzure::DeleteNode; delete_node(File.expand_path(File.dirname(File.dirname(__FILE__))))"`
  if [ $? -ne 0 ]; then
    echo "Unable to delete ths node.."
    exit 1
  else
    echo "Node deleted from chef server successfully."
  fi
}

if [ -f $update_process_descriptor ]; then
  echo "[$(date)] Not doing uninstall, as the update process is running"
  rm $update_process_descriptor
else
  # Uninstall the custom gem
  azure_chef_extn_gem=`gem list azure-chef-extension | grep azure-chef-extension | awk '{print $1}'`

  # Call to delete node and client from chef server
  delete_node

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
fi
