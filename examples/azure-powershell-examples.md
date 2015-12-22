# Microsoft Azure PowerShell for Windows
This project provides a set of PowerShell cmdlets for developers and IT administrators to develop, deploy and manage Microsoft Azure applications
* [Azure PowerShell](https://github.com/Azure/azure-powershell)

## Chef related Azure PowerShell Cmdlets:
#### Set-AzureVMChefExtension
#####Set-AzureVMChefExtension -ValidationPem \<string\> -Windows -VM \<IPersistentVM\> [-Version \<string\>] [-ClientRb \<string\>] [-BootstrapOptions \<string\>] [-RunList \<string\>] [-ChefServerUrl \<string\>] [-ValidationClientName \<string\>] [-OrganizationName \<string\>] [-AutoUpdateChefClient] [-DeleteChefConfig]
This cmdlets is used to Set Chef Extension on given azure VM.
##### Options:
* -RunList
The Chef Server Node Runlist.
* -ValidationPem
The Chef Server Validation Key File Path.
* -ValidationClientName
The Chef ValidationClientName, used to determine whether a chef-client may register with a Chef server.
* -ClientRb
The Chef Server Client Config (ClientRb)File Path.
* -AutoUpdateChefClient
Flag to opt for auto chef-client update. Chef-client update is false by default.
* -BootstrapOptions
Bootstrap options in JSON format. Ex: -j '{"chef_node_name":"test_node"}'
* -DeleteChefConfig
Delete the chef config files during update/uninstall extension. Default is false.
* -ChefServerUrl
The Chef Server Url.
* -OrganizationName
The Chef Organization name, used to form Validation Client Name.
* -Version
The Extension Version. Default is the latest available version
* -Windows
Set extension for Windows.
* -Linux
Set extension for Linux.

##### Example 1: Create Windows VM with Chef Extension -
```bash
$vm1 = "azurechefwin"
$svc = "azurechefwin"
$username = 'azure'
$password = 'azure@123'
 
$img = "a699494373c04fc0bc8f2bb1389d6106__Windows-Server-2012-R2-201406.01-en.us-127GB.vhd"
 
$vmObj1 = New-AzureVMConfig -Name $vm1 -InstanceSize Small -ImageName $img
 
$vmObj1 = Add-AzureProvisioningConfig -VM $vmObj1 -Password $password -AdminUsername $username –Windows
 
# set azure chef extension
$vmObj1 = Set-AzureVMChefExtension -VM $vmObj1 -ValidationPem "C:\\users\\azure\\msazurechef-validator.pem" -ClientRb 
"C:\\users\\azure\\client.rb" -RunList "getting-started" -Windows

New-AzureVM -Location 'West US' -ServiceName $svc -VM $vmObj1

```

##### Example 2: Create Linux VM with Chef Extension -
```bash
$vm1 = "azurecheflnx"
$svc = "azurecheflnx"
$username = 'azure'
$password = 'azure@123'

# CentOS image id
$img = "5112500ae3b842c8b9c604889f8753c3__OpenLogic-CentOS-71-20150605"
OR
# Ubuntu image id
$img = "b39f27a8b8c64d52b05eac6a62ebad85__Ubuntu-12_04_5-LTS-amd64-server-20150127-en-us-30GB"
 
$vmObj1 = New-AzureVMConfig -Name $vm1 -InstanceSize Small -ImageName $img
 
$vmObj1 = Add-AzureProvisioningConfig -VM $vmObj1 -Password $password -Linux -LinuxUser $username
 
# set azure chef extension
$vmObj1 = Set-AzureVMChefExtension -VM $vmObj1 -ValidationPem "C:\\users\\azure\\msazurechef-validator.pem" -ClientRb 
"C:\\users\\azure\\client.rb" -RunList "getting-started" -Linux

New-AzureVM -Location 'West US' -ServiceName $svc -VM $vmObj1

```

#### Get-AzureVMChefExtension
#####  Get-AzureVMChefExtension -VM \<IPersistentVM\>
This cmdlets is used to Get Chef Extension details from given azure VM.

##### Example:
```bash

#Get Chef Extension - 

Get-AzureVM -ServiceName cloudservice1 -Name azurevm1 | Get-AzureVMExtension

```

**ARM commands for Azure Chef Extension**

1. For windows, create ARM template file referring https://github.com/Azure/azure-quickstart-templates/blob/master/chef-extension-windows-vm/azuredeploy.json. Create ARM parameter file referring https://github.com/Azure/azure-quickstart-templates/blob/master/chef-extension-windows-vm/azuredeploy.parameters.json

2. For linux, create ARM template file referring https://github.com/Azure/azure-quickstart-templates/blob/master/chef-json-parameters-ubuntu-vm/azuredeploy.json. Create ARM parameter file referring https://github.com/Azure/azure-quickstart-templates/blob/master/chef-json-parameters-ubuntu-vm/azuredeploy.parameters.json

3. Use code given below as per your platform in the given sequence to encode validation key in your ARM's parameters Json template:

```javascript

A. Windows

$validation_key = sed ':a;N;$!ba;s/\n/\\n/g' <path_to_validator_pem_file>

$validation_key


B. Linux

validation_key=$(sed ':a;N;$!ba;s/\n/\\n/g' <path_to_validator_pem_file>)

echo $validation_key

```
**Note:** 
-- For both the platforms, copy the output of 2nd command and paste as it is into `validation_key` attribute of your ARM's parameters Json template.
-- Make the necessary validator_pem_file_path changes in the above commands as per your configuration.

4. Refer code written below

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
http://azure.microsoft.com/en-us/documentation/templates/chef-json-parameters-ubuntu-vm/
http://azure.microsoft.com/en-us/documentation/templates/multi-vm-chef-template-ubuntu-vm/

