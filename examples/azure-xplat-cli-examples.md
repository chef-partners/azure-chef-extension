# Microsoft Azure Xplat-CLI for Windows, Mac and Linux
This project provides a cross-platform command line interface for developers and IT administrators to develop, deploy and manage Microsoft Azure applications
* [Azure-Xplat-CLI](https://github.com/Azure/azure-xplat-cli)

## Chef related Azure CLI Commands:
#### azure vm extension set-chef < vm-name > [ options ]
This command is used to Set Chef Extension on given azure VM.
##### Options:
* -V < number > or --version < number >
Extension's version number. Default is latest.
* -R < run-list > or  --run-list < run-list > 
Runlist of roles/recipes to apply to VM
* -O < validation-pem > or --validation-pem < validation-pem > 
Chef validation pem file path
* -c < client-config > or  --client-config < client-config >
Chef client configuration file (i.e client.rb) path
* -a or --auto-update-client
Auto update chef client
* -b or --disable
Disable extension
* -u or --uninstall
Uninstall extension
* -C < client-pem > or  --client-pem < client-pem >
Chef client pem file path i.e required in validator less bootstrap
* -j < bootstrap-json-attribute > or  --bootstrap-options < bootstrap-json-attribute >
Bootstrap options in JSON format. Ex: -j '{"chef_node_name":"test_node"}'
* -D or --delete-chef-config
Delete chef config files during update/uninstall extension


##### Example:
```bash
#Create VM -
#For more command options please refer: http://azure.microsoft.com/en-us/documentation/articles/virtual-machines-command-line-tools/#Commands_to_manage_your_Azure_virtual_machines 
azure vm create your-vm-name MSFT__Windows-Server-2008-R2-SP1.11-29-2011 yourusername yourpassword --location "West US" -r

#Set Chef Extension (*Without RunList) - 
azure vm extension set-chef your-vm-name --validation-pem ~/chef-repo/.chef/testorg-validator.pem --client-config ~/chef-repo/.chef/client.rb --version "1201.12"

#Set Chef Extension (*With RunList) -
azure vm extension set-chef your-vm-name --validation-pem ~/chef-repo/.chef/testorg-validator.pem --client-config ~/chef-repo/.chef/client.rb --version "1201.12" -R 'recipe[your_cookbook_name::your_recipe_name]'

```
#### azure vm extension get-chef < vm-name > [ options ]
This command is used to Get Chef Extension details from given azure VM.

##### Example:
```bash

#Get Chef Extension - 
azure vm extension get-chef your-vm-name

```