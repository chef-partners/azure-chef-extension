trap [Exception] {echo $_.Exception.Message;exit 1}

# Source the shared PS
$chefExtensionRoot = ("{0}{1}" -f (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition), "\\..")
. $chefExtensionRoot\\bin\\shared.ps1

# powershell has in built cmdlets: ConvertFrom-Json and ConvertTo-Json which are supported above PS v 3.0
# so the hack - use ruby json parsing for versions lower than 3.0
if ($PSVersionTable.PSVersion.Major -ge 3)
{
  $json_handlerSettingsFileName, $json_handlerSettings, $json_protectedSettings,  $json_protectedSettingsCertThumbprint, $json_client_rb , $json_runlist, $json_chefLogFolder, $json_statusFolder, $json_heatbeatFile = readJsonFile
}
else
{
   readJsonFileUsingRuby
}

Write-ChefStatus "stopping-chef-service" "transitioning" "Stopping Chef Service"

# Call chef service manager to stop the chef service
$env:Path += ";C:\\opscode\\chef\\bin;C:\\opscode\\chef\\embedded\\bin"

# stop the chef service
$result = chef-service-manager -a stop

if ($result -match "Service 'chef-client' is now 'stopped'.")
{ Write-ChefStatus "chef-service-stop" "success" "Chef Service stopped successfully"}
else
{ Write-ChefStatus "chef-service-stop" "error" $result }