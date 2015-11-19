# Knife Azure Plugin
A knife plugin to create, delete, and enumerate Microsoft Azure resources to be managed by Chef. The knife azure subcommand is used to manage API-driven cloud servers that are hosted by Microsoft Azure.

* [Knife-Azure](https://github.com/chef/knife-azure)

## Azure Chef Extension related knife commands:

#### knife azure server create
##### knife azure server create -I \<image_id\> --azure-vm-size Medium -x \<user_name\> -P 'azure@123' --bootstrap-protocol 'cloud-api' -c '~\chef-repo\.chef\knife.rb' --azure-service-location "West US" -VV

**Note:** --bootstrap-protocol 'cloud-api' is used to set chef extension on VM.
##### Options:
*  -r or --run-list
The Chef Server Node Runlist.
* -j or --json-attributes
 A JSON string to be added to the first run of chef-client.
* --azure-extension-client-config
Optional. Path to client.rb file that gets copied over the azure-chef-extension.
* --auto-update-client
Set this flag to enable auto chef client update in azure chef extension. This flag should be used with cloud-api bootstrap protocol only.
* --delete-chef-extension-config
Determines whether Chef configuration files removed when Azure removes the Chef resource extension from the VM. This option is only valid for the 'cloud-api' bootstrap protocol. The default is false.
* --bootstrap-version
Applicable for only ubuntu and centos. Chef-client's version to be installed on the VM can be specified with this option. By default chef-client's latest version gets installed.

Supported bootstrap_options from knife azure:
  * --environment
  * --node-name
  * --secret-file
  * --server-url
  * --[no-]node-verify-api-cert
  * --bootstrap-version
  * --node-ssl-verify-mode

##### Example 1: Create Windows VM with Chef Extension -
```bash
knife azure server create -I "a699494373c04fc0bc8f2bb1389d6106__Windows-Server-2012-Datacenter-201411.01-en.us-127GB.vhd" --azure-vm-size Medium -x 'azureuser' -P 'azure@123' --bootstrap-protocol 'cloud-api' -c '~/chef-repo/.chef/knife.rb' -r 'recipe[getting-started]' --azure-service-location "West US" -VV
```

##### Example 2: Create Linux VM with Chef Extension -
```bash
knife azure server create -I "b39f27a8b8c64d52b05eac6a62ebad85__Ubuntu_DAILY_BUILD-trusty-14_04_1-LTS-amd64-server-20140902-en-us-30GB" --azure-vm-size Medium -x 'azureuser' -P 'azure@123' --bootstrap-protocol 'cloud-api' -c '~/chef-repo/.chef/knife.rb' -r 'recipe[getting-started]' --azure-service-location "West US" -VV
```
