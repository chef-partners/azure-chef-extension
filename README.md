#azure-chef-extension

Azure resource extension to enable Chef on Azure virtual machine instances.

##Features:

1. It can be installed through Azure RESTFUL API for extension
2. The execution output of the scripts is logged in the log directory specified in HandlerEnvironment.json
3. Status of the extension is reported back to Azure so that user can see the status on Azure Portal

##Platforms and version its supported:

| Platform | Version    |
|----------|------------|
| Ubuntu   | 12.04, 14+  |
| Windows  | 2008r2, 2012, 2012r2 |


##Azure Chef Extension usage:
#####Options that can be set in publicconfig.config
```javascript
{
  "client_rb": "< your client.rb configuration >".
  "runlist":"< your run list >",
  "autoUpdateClient":"< true|false >",
  "deleteChefConfig":"< true|false >",
  "bootstrap_options": {
    "chef_node_name":"< your node name >",
    "chef_server_url":"< your chef server url >",
    "validation_client_name":"< your chef organization validation client name  >"
  }
}
```
`client_rb`: Set this option to specify the configuration details for the chef-client. Refer to [client.rb] (https://docs.chef.io/config_rb_client.html)

`run_list`: A run-list defines all of the information necessary for Chef to configure a node into the desired state.
It is an ordered list of roles and/or recipes that are run in the exact order defined in the run-list.

`autoUpdateClient` : Set this option to true to auto udpate chef extension version. By default it's set to false.  Extension's Hotfix versions are auto-updated on the VM when the VM is restarted. for e.g.: A VM that has 1205.12.2.0, gets auto updated to 1205.12.2.1 when 1205.12.2.1 is published.
This option should be set to true for updating the extension manually also.

`deleteChefCofig`: Set deleteChefConfig option to true in publicconfig if you want to delete chef configuration files while update or uninstall. By default it is set to false.

`bootstrap_options`: Set bootstrap options while adding chef extension to Azure VM. Bootstrap options used by Chef-Client during node converge. It overrides the configuration set in client_rb option. for e.g. node_name option i.e. if you set node_name as "foo" in the client_rb and in bootstrap_option you set chef_node_name as "bar" it will take "bar" as node name instead of "foo".

***Supported options in bootstrap_options json:***  `chef_node_name`, `chef_server_url`, `validation_client_name`, `environment`, `chef_node_name`, `secret`

***Note***: chef_server_url and validation_client_name are mandatory to pass for the node to bootstrap.

publicconfig.config example:

```javascript
{
  "client_rb": "chef_server_url  \"https://api.opscode.com/organizations/some-org\"\nvalidation_client_name   \"some-org-validator\"\nclient_key    \"c:/chef/client.pem\"\nvalidation_key    \"c:/chef/validation.pem\"",
  "runlist":"recipe[getting-started]",
  "autoUpdateClient":"true",
  "deleteChefConfig":"false",
  "bootstrap_options": {
    "chef_node_name":"mynode3",
    "chef_server_url":"https://api.opscode.com/organizations/some-org",
    "validation_client_name":"some-org-validator"
  }
}
```

#####Options that can be set in privateconfig.config
```javascript
{
  "validation_key": "<your chef organisation validation key>"
}
```

**Following are the References to doc for different Azure command line tools**

| Client                    | How to use                                                   |
|---------------------------|--------------------------------------------------------------|
| Azure portal              | https://docs.chef.io/azure_portal.html                       |
| Azure Powershell cmdlets  | https://msdn.microsoft.com/en-us/library/azure/dn874067.aspx |
| Knife cloud api bootstrap | https://docs.chef.io/plugin_knife_azure.html                 |
| Azure Xplat CLI           | https://gist.github.com/siddheshwar-more/9f3e412d773ef57780fc |


**Powershell script to try Azure Chef Extension by using Set-AzureVMExtension cmdlet:**

```javascript
$vm1 = "<VM name>"
$svc = "<VM name>"
$username = "<username>"
$password = "<password>"

$img = "<your windows image>"

$vmObj1 = New-AzureVMConfig -Name $vm1 -InstanceSize Small -ImageName $img

$vmObj1 = Add-AzureProvisioningConfig -VM $vmObj1 -Password $password -AdminUsername $username –Windows

# use the shared config files
# ExtensionName = ChefClient(for windows), LinuxChefClient (for ubuntu)
$vObj1 = Set-AzureVMExtension -VM $vmObj1 -ExtensionName ‘ChefClient’ -Publisher ‘Chef.Bootstrap.WindowsAzure’ -Version 11.12 -PublicConfigPath '<your path to publiconfig.config>' -PrivateConfigPath '<your path to privateconfig.config>'

New-AzureVM -Location 'West US' -ServiceName $svc -VM $vObj1

# Look into your hosted chef account to verify the registerd node(VM)
```

**Updating Extension manually**

1. Suppose you have a VM with extension version 1205 .12
2. `$vmm = Get-AzureVM -Name "<vm-name>" -ServiceName "<cloud-service-name>"`
3. Set `autoUpdateClient` to true in publicconfig.config file
4. Update to latest version- Ex- 1206.12
```
$vmOb = Set-AzureVMExtension -VM $vmm -ExtensionName 'ChefClient' -Publisher ‘Chef.Bootstrap.WindowsAzure’ -Version '1206.12' -PublicConfigPath 'path\\to\\publicconfig.config' -PrivateConfigPath 'path\\to\\privateconfig.config'

Update-AzureVM -VM $vmOb.VM -Name "<vm-name>" -ServiceName "<cloud-service-name>
```

##Azure Chef Extension Version Scheme

**Description:**

Extensions versions are specified in 4 digit format : `<MajorVersion.MinorVersion.BuildNumber.RevisionNumber>`.

Chef Extension package includes released Chef-Client package. Currently Extension version depends on Chef-Client version. So whenever new Chef Client is releases, we have to publish new Extension as well.

Chef-Client versions are specified in 4 digit format: `<MajorVersion.MinorVersion.PatchVersion-RevisionNumber>`. Example: chef-client 11.14.6-1

**Use Following Extension Version Scheme:**
* We are using Extension Major version from `1100.*.*.*`
* Set Extension Minor Version = Chef-Client's Major Version
* Set Extension BuildNumber = Chef-Client's Minor Version
* Set Extension RevisionNumber = Chef-Client's PatchVersion
* Whenever Chef-Client 'Major' Version changes, increase Extension 'Major' Version by '+100'. When 'Minor' Version changes, increase Extension 'Major' Version by '+1'.

**Example**

    1. When Chef-Client Major Version Changes-
    Consider,
    Current Chef-Client Version is 11.14.6-1

    Current Extension Version is 1100.11.14.6

    # Chef-Client Major version changed
    After new Client-Client Version 12.0.0-1 is released

    # Increase Extension Major version by +100
    New Extension Version will be 1200.12.0.0

    2. When Chef Client Minor Version Changes-
    Consider,
    Current Chef-Client Version is 11.14.6-1

    Current Extension Version is 1100.11.14.6

    # Chef-Client Minor version changed
    After new Client-Client Version 11.16.0-1 is released

    # Increase Extension Major version by +1
    New Extension Version will be 1101.11.16.0

##Build and Packaging
You can use rake tasks to build and publish the new builds to Azure subscription.

**Note:** The arguments have fix order and recommended to specify all for readability and avoiding confusion.

#####Build
    rake build[:target_type, :extension_version, :confirmation_required]

:target_type = [windows/ubuntu/centos] default is windows

:extension_version = Chef extension version, say 11.6 [pattern major.minor governed by Azure team]

:confirmation_required = [true/false] defaults to true to generate prompt.

    rake 'build[ubuntu,11.6]'

#####Publish
Rake task to generate a build and publish the generated zip package to Azure.

    rake publish[:deploy_type, :target_type, :extension_version, :chef_deploy_namespace, :operation, :internal_or_public, :confirmation_required]

The task depends on:
  * cli parameters listed below.
  * entries in Publish.json.
  * environment variable "publishsettings" set pointing to the publish setting file.
  [Environment]::SetEnvironmentVariable("publishsettings", 'C:\myaccount.publishsettings', "Process")


:deploy_type = [deploy_to_preview/deploy_to_prod] default is preview

:target_type = [windows/ubuntu/centos] default is windows

:extension_version = Chef extension version, say 11.6 [pattern major.minor governed by Azure team]

:chef_deploy_namespace = "Chef.Bootstrap.WindowsAzure.Test".

:operation = [new/update]

:internal_or_public = [confirm_public_deployment/confirm_internal_deployment]

:confirmation_required = [true/false] defaults to true to generate prompt.


    rake 'publish[deploy_to_production,ubuntu,11.6,Chef.Bootstrap.WindowsAzure.Test,update,confirm_internal_deployment]'

#####Delete
Rake task to delete a published package to Azure.
**Note:**
Only internal packages can be deleted.

    rake delete[:deploy_type, :target_type, :chef_deploy_namespace, :full_extension_version, :confirmation_required]

The task depends on:
  * cli parameters listed below.
  * environment variable "publishsettings" set pointing to the publish setting file.

  :deploy_type = [delete_from_preview/delete_from_prod] default is preview

  :full_extension_version = Chef extension version, say 11.12.4.1 [Version as specified during the publish call]

  :target_type, :chef_deploy_namespace and :confirmation_required = same as for publish task.

    rake 'delete[delete_from_production,ubuntu,Chef.Bootstrap.WindowsAzure.Test,11.12.4.2]'

#####Update
Rake task to udpate a published package to Azure. Used to switch published versions from "internal" to "public" and vice versa. You need to know the build date.

    rake update[:deploy_type, :target_type, :extension_version, :build_date_yyyymmdd, :chef_deploy_namespace, :internal_or_public, :confirmation_required]

The task depends on:
  * cli parameters listed below. All params definition as same as publish task except build date.
  * environment variable "publishsettings" set pointing to the publish setting file.

  :build_date_yyyymmdd = The build date when package was published, in format yyyymmdd

    rake 'update[deploy_to_production,windows,11.12.4.2,20140530,Chef.Bootstrap.WindowsAzure.Test,confirm_internal_deployment]'
