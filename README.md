# azure-chef-extension

Azure resource extension to enable Chef on Azure virtual machine instances.

## Features:

1. It can be installed through Azure RESTFUL API for extension
2. The execution output of the scripts is logged in the log directory specified in HandlerEnvironment.json
3. Status of the extension is reported back to Azure so that user can see the status on Azure Portal

## Platforms and version its supported:

| Platform | Version    |
|----------|------------|
| Ubuntu   | 12.04, 14+  |
| Windows  | 2008r2+    |
| Centos   | 6.5+                 |
| RHEL     | 6+         |
| Debian   | 7,8        |
### Microsoft Windows Images
The extension is tested against the offical Microsoft images on Azure listed below. If you have issues and you're using a different Windows image please provide that information in any issues filed.

| Version | Image  |
|---------| -------|
| 2008r2  | a699494373c04fc0bc8f2bb1389d6106__Win2K8R2SP1-Datacenter-20170406-en.us-127GB.vhd |
| 2012    | a699494373c04fc0bc8f2bb1389d6106__Windows-Server-2012-Datacenter-20170406-en.us-127GB.vhd |
| 2012r2  | a699494373c04fc0bc8f2bb1389d6106__Windows-Server-2012-R2-20170406-en.us-127GB.vhd |

**Note**: `Windows Server 2008 R2` gives timeout error intermittently while installing extention when using ASM command `Set-AzureVMExtension`. But it works successfully with other ASM commands and Xplat commands.

## Azure Chef Extension usage:
##### Options that can be set in publicconfig.config
```javascript
{
  "client_rb": "< your additions to the client.rb configuration >".
  "runlist":"< your run list >",
  "validation_key_format": "< plaintext|base64encoded >",
  "bootstrap_version": "< version of chef-client >",
  "daemon": "< none/service/task >"
  "environment_variables": {
    "< comma separated list of key-value pairs >"
  },
  "chef_daemon_interval": "< frequency at which the chef-client runs as service or as scheduled task >",
  "custom_json_attr": {
    "< comma separated list of key-value pairs >"
  },
  "bootstrap_options": {
    "chef_node_name":"< your node name >",
    "chef_server_url":"< your chef server url >",
    "validation_client_name":"< your chef organization validation client name  >"
  }
}
```
`client_rb`: Set this option to specify additional configuration details for the chef-client. Additions are appended to the top of the client.rb file.  Refer to [client.rb] (https://docs.chef.io/config_rb_client.html)

`run_list`: A run-list defines all of the information necessary for Chef to configure a node into the desired state.
It is an ordered list of roles and/or recipes that are run in the exact order defined in the run-list.

`validation_key_format`: Specifies the format in which `validation_key` is set in the `privateconfig.config` file. Supported values are `plaintext` and `base64encoded`. Default value is `plaintext`.

`bootstrap_version`: Set the version of `chef-client` to be installed on the VM.

`daemon`: Supported only on Windows extension. Configures the chef-client as service or as scheduled task for unattended execution. Supported values are `none`, `service` and 'task'. Default is `service`.
`none` prevents the chef-client service from being configured as a service.
`service` configures chef-client as a service.
`task` configures chef-client as a scheduled task for defined interval. Default value is 30 mins.

`environment_variables`: Specifies the list of environment variables (like the environment variables for proxy server configuration) to be available to the Chef Extension scripts.

`chef_daemon_interval`: Specifies the frequency (in minutes) at which the `chef-client` runs as `service` or as `scheduled task`. If in case you don't want the `chef-service` or `scheduled task` to be installed on the Azure VM then set value as `0` in this field. At any time you can change the interval value using the `Set-AzureVMExtension` command with the new interval passed in the `publicconfig.config` file (pass `0` if you want to delete the already installed chef-service on the Azure VM). Default value is `30` minutes.

`custom_json_attr`: Specifies a JSON string to be added to the first run of chef-client.

`bootstrap_options`: Set bootstrap options while adding chef extension to Azure VM. Bootstrap options used by Chef-Client during node converge. It overrides the configuration set in client_rb option. for e.g. node_name option i.e. if you set node_name as "foo" in the client_rb and in bootstrap_option you set chef_node_name as "bar" it will take "bar" as node name instead of "foo".

***Supported options in bootstrap_options json:***  `chef_node_name`, `chef_server_url`, `validation_client_name`, `environment`, `secret`

***Note***: chef_server_url and validation_client_name are mandatory to pass for the node to bootstrap.

publicconfig.config example:

```javascript
{
  "client_rb": "chef_server_url  \"https://api.opscode.com/organizations/some-org\"\nvalidation_client_name   \"some-org-validator\"\nclient_key    \"c:/chef/client.pem\"\nvalidation_key    \"c:/chef/validation.pem\"",
  "runlist":"recipe[getting-started]",
  "validation_key_format": "plaintext",
  "environment_variables": {
    "variable_1": "value_1",
    "variable_2": "value_2",
    ...
    "variable_n": "value_n"
  },
  "chef_daemon_interval": "18",
  "daemon": "none",
  "custom_json_attr": {
    "container_service": { "chef-init-test": { "command": "C:\\opscode\\chef\\bin" } }
  },
  "bootstrap_options": {
    "chef_node_name":"mynode3",
    "chef_server_url":"https://api.opscode.com/organizations/some-org",
    "validation_client_name":"some-org-validator"
  }
}
```

##### Options that can be set in privateconfig.config
```javascript
{
  "validation_key": "<your chef organisation validation key as a JSON escaped string>",
  "secret": "<your encrypted data bag secret key contents>"
}
```

#### Following are the References to doc for different Azure command line tools

1. [Azure portal](https://docs.chef.io/azure_portal.html)
2. [Azure Powershell cmdlets](examples/azure-powershell-examples.md)
3. [Azure Xplat CLI](examples/azure-xplat-cli-examples.md)
4. [Knife Azure Plugin](examples/knife-azure-plugin-examples.md)

#### Powershell script to try Azure Chef Extension by using Set-AzureVMExtension cmdlet:

```javascript
$vm1 = "<VM name>"
$svc = "<VM name>"
$username = "<username>"
$password = "<password>"

$img = "<your windows image>"

$vmObj1 = New-AzureVMConfig -Name $vm1 -InstanceSize Small -ImageName $img

$vmObj1 = Add-AzureProvisioningConfig -VM $vmObj1 -Password $password -AdminUsername $username –Windows

# use the shared config files
# ExtensionName = ChefClient(for windows), LinuxChefClient (for ubuntu and centos)
$vObj1 = Set-AzureVMExtension -VM $vmObj1 -ExtensionName ‘ChefClient’ -Publisher ‘Chef.Bootstrap.WindowsAzure’ -Version 1210.12 -PublicConfigPath '<your path to publiconfig.config>' -PrivateConfigPath '<your path to privateconfig.config>'

New-AzureVM -Location 'West US' -ServiceName $svc -VM $vObj1

# Look into your hosted chef account to verify the registerd node(VM)
```

#### Updating Extension manually

1. Suppose you have a VM with extension version 1205 .12
2. `$vmm = Get-AzureVM -Name "<vm-name>" -ServiceName "<cloud-service-name>"`
3. Update to latest version- Ex- 1206.12
```
$vmOb = Set-AzureVMExtension -VM $vmm -ExtensionName 'ChefClient' -Publisher ‘Chef.Bootstrap.WindowsAzure’ -Version '1206.12' -PublicConfigPath 'path\\to\\publicconfig.config' -PrivateConfigPath 'path\\to\\privateconfig.config'

Update-AzureVM -VM $vmOb.VM -Name "<vm-name>" -ServiceName "<cloud-service-name>
```

#### ARM commands for Azure Chef Extension

1. Please refer https://github.com/Azure/azure-quickstart-templates/tree/master/chef-json-parameters-linux-vm of creating the ARM template files.

2. Find below some advanced options that can be set in the Azure ARM template file `azuredeploy.json`:
  - `environment_variables`: Specifies the list of environment variables (like the environment variables for proxy server configuration) to be available to the Chef Extension scripts.
  - `hints`: Specifies the Ohai Hints to be set in the Ohai configuration of the target node.

  ***Note***: Set both these options under `properties` --> `settings` section of the `Microsoft.Compute/virtualMachines/extensions` resource type as shown in the below example:

  Example:

  ```javascript
  {
    "type": "Microsoft.Compute/virtualMachines/extensions",
    "name": "[concat(variables('vmName'),'/', variables('vmExtensionName'))]",
    "apiVersion": "2015-05-01-preview",
    "location": "[resourceGroup().location]",
    "dependsOn": [
      "[concat('Microsoft.Compute/virtualMachines/', variables('vmName'))]"
    ],
    "properties": {
      "publisher": "Chef.Bootstrap.WindowsAzure",
      "type": "LinuxChefClient",
      "typeHandlerVersion": "1210.12",
      "settings": {
        "bootstrap_options": {
          "chef_node_name": "[parameters('chef_node_name')]",
          "chef_server_url": "[parameters('chef_server_url')]",
          "validation_client_name": "[parameters('validation_client_name')]"
        },
        "runlist": "[parameters('runlist')]",
        "validation_key_format": "[parameters('validation_key_format')]",
        "environment_variables": {
          "variable_1": "value_1",
          "variable_2": "value_2",
          "variable_3": "value_3"
        },
        "chef_daemon_interval": "18",
        "daemon" : "service",
        "custom_json_attr": {
          "container_service": { "chef-init-test": { "command": "C:\\opscode\\chef\\bin" } }
        },
        "hints": {
          "public_fqdn": "[reference(variables('publicIPAddressName')).dnsSettings.fqdn]",
          "vm_name": "[reference(variables('vmName'))]"
        }
      },
      "protectedSettings": {
        "validation_key": "[parameters('validation_key')]",
        "secret": "[parameters('secret')]"
      }
    }
  }
```

3. Refer code written below

```javascript
Switch-AzureMode -Name AzureResourceManager
Select-AzureSubscription -SubscriptionName <subscription_name>
Add-AzureAccount

$pathtemp='path/to/azuredeploy.json' # Refer above mentioned #1 and #2
$pathtempfile='path/to/azuredeploy.parameters.json' # Refer above #1 and #2

New-AzureResourceGroup -Name '<resource_group_name>' -Location '<location>'
New-AzureResourceGroupDeployment -Name <deployment_name> -TemplateParameterFile $pathtempfile -TemplateFile $pathtemp -ResourceGroupName '<resource_group_name>'
```

**References:**
https://azure.microsoft.com/en-us/resources/templates/chef-json-parameters-linux-vm/
https://azure.microsoft.com/en-us/resources/templates/multi-vm-chef-template-ubuntu-vm/

**Note:** If there are more than one extensions in your ARM template then sequencing of the extensions may be required to avoid conflicts. Add the Chef Extension at the end as the run is likely to be longer.



## Azure Chef Extension Version Scheme

**Description:**

The version scheme is moved to 1210.12.100 after the version 1210.12.5.1.
This is done since extension version and `chef-client` version are decoupled.

Extensions versions are specified in 4 digit format : `<MajorVersion.MinorVersion.BuildNumber.RevisionNumber>`, where major version is freezed as `1210`.
If backward incompatible changes are made, MinorVersion is increased by 1.
If a backward compatible functionaly is added, BuildNumber is increased by 1.
If there is no patch applied, then RevisionNumber is not set. On applying patch, initial RevisionNumber is set to 1000. After that extension's RevisionNumber is increased by 1 for consequent patches.

**Example**

    1. When a patch is applied to extension-
    Consider,
    Current Extension Version is 1210.12.100

    # After applying patch, RevisionNumber is set to 1000
    RevisionNumber = 1000

    New Extension Version will be 1210.12.100.1000

    # If another patch is applied, RevisionNumber is incremented by 1
    RevisionNumber = 1001

    Hence Extension Version will be 1210.12.100.1001

## Old Version Scheme

**Description:**

Previously the extension version was coupled with the `chef-client` version.
Extension versions were specified in 4 digit format : `<MajorVersion.MinorVersion.BuildNumber.RevisionNumber>`, where major version was freezed as `1210`.

Chef-Client versions are specified in 4 digit format: `<MajorVersion.MinorVersion.PatchVersion-RevisionNumber>`. Example: chef-client 12.4.1-1

**The Extension Version Scheme was as follows:**
* Extension Major version is freezed as `1210.*.*.*`
* Extension Minor Version = Chef-Client's Major Version
* Extension BuildNumber = Chef-Client's Minor Version
* Extension RevisionNumber = Chef-Client's PatchVersion * 1000
* When a patch is applied to extension, extension's RevisionNumber is increased by 1.

**Example**

    1. When Chef-Client Version Changes-
    Consider,
    Current Chef-Client Version is 12.4.1

    # Extension's RevisionNumber is Chef-Client's PatchVersion * 1000
    Current Extension Version is 1210.12.4.1000

    # Chef-Client version changes
    After new Client-Client Version 12.4.2 is released

    New Extension Version will be 1210.12.4.2000

    2. When a patch is applied to extension while Chef-Client's version is same-
    Current Chef-Client Version is 12.4.1

    # Extension's RevisionNumber is Chef-Client's PatchVersion * 1000
    Current Extension Version is 1210.12.4.1000

    # After applying patch to Extension increase extension's RevisionNumber by 1
    New Extension Version will be 1210.12.4.1001

## Tagging
We tag the extension with every extension publish. We have started tagging from extension 1206.12.3.0. Prior to that tags are not available.
Before tagging we update the README(if required), CHANGELOG and RELEASE_NOTES.

## Build and Packaging
You can use rake tasks to build and publish the new builds to Azure subscription.

**Note:** The arguments have fixed order and recommended to specify all for readability and avoiding confusion.

##### Build
    rake build[:target_type, :extension_version, :confirmation_required]

:target_type = [windows/ubuntu/centos] default is windows

:extension_version = Chef extension version, say 1210.12 [pattern major.minor governed by Azure team]

:confirmation_required = [true/false] defaults to true to generate prompt.

    rake 'build[ubuntu,1210.12]'

##### Publish
Rake task to generate a build and publish the generated zip package to Azure.

    rake publish[:deploy_type, :target_type, :extension_version, :chef_deploy_namespace, :operation, :internal_or_public, :confirmation_required]

The task depends on:
  * cli parameters listed below.
  * entries in Publish.json.
  * environment variable "publishsettings" set pointing to the publish setting file.
  [Environment]::SetEnvironmentVariable("publishsettings", 'C:\myaccount.publishsettings', "Process")


:deploy_type = [deploy_to_preview/deploy_to_prod] default is preview

:target_type = [windows/ubuntu/centos] default is windows

:extension_version = Chef extension version, say 1210.12 [pattern major.minor governed by Azure team]

:chef_deploy_namespace = "Chef.Bootstrap.WindowsAzure.Test".

:operation = [new/update]

:internal_or_public = [confirm_public_deployment/confirm_internal_deployment]

:confirmation_required = [true/false] defaults to true to generate prompt.


    rake 'publish[deploy_to_production,ubuntu,1210.12,Chef.Bootstrap.WindowsAzure.Test,update,confirm_internal_deployment]'

##### Delete
Rake task to delete a published package to Azure.
**Note:**
Only internal packages can be deleted.

    rake delete[:deploy_type, :target_type, :chef_deploy_namespace, :full_extension_version, :confirmation_required]

The task depends on:
  * cli parameters listed below.
  * environment variable "publishsettings" set pointing to the publish setting file.

  :deploy_type = [delete_from_preview/delete_from_prod] default is preview

  :full_extension_version = Chef extension version, say 1210.12.4.1000 [Version as specified during the publish call]

  :target_type, :chef_deploy_namespace and :confirmation_required = same as for publish task.

    rake 'delete[delete_from_production,ubuntu,Chef.Bootstrap.WindowsAzure.Test,1210.12.4.1000]'

##### Update
Rake task to udpate a published package to Azure. Used to switch published versions from "internal" to "public" and vice versa. You need to know the build date.

    rake update[:deploy_type, :target_type, :extension_version, :build_date_yyyymmdd, :chef_deploy_namespace, :internal_or_public, :confirmation_required]

The task depends on:
  * cli parameters listed below. All params definition as same as publish task except build date.
  * environment variable "publishsettings" set pointing to the publish setting file.

  :build_date_yyyymmdd = The build date when package was published, in format yyyymmdd

    rake 'update[deploy_to_production,windows,1210.12.4.1000,20140530,Chef.Bootstrap.WindowsAzure.Test,confirm_internal_deployment]'

**Note:** Old extensions will not be available as there is a limit on the number of published extensions.
