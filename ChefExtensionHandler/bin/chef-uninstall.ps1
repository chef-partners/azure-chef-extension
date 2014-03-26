trap [Exception] {echo $_.Exception.Message;exit 1}

# uninstall chef
# Actions:
#    - disable chef service and remove service
#    - uninstall chef

# Source the shared PS
$chefExtensionRoot = ("{0}{1}" -f (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition), "\\..")
. $chefExtensionRoot\\bin\\shared.ps1

$env:Path += ";C:\opscode\chef\bin;C:\opscode\chef\embedded\bin"

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

if (!(Test-ChefExtensionRegistry))
{
  Write-ChefStatus "uninstalling-chef" "transitioning" "Uninstalling Chef"

  $bootstrapDirectory = "C:\\chef"
  $chefInstallDirectory = "C:\\opscode"

  # uninstall does both disable and remove the service
  $result = chef-service-manager -a uninstall
  echo $result

  # Uninstall the custom gem
  $result = gem uninstall -Ix azure-chef-extension
  echo $result

  # Actual uninstall functionality
  # Get chef_pkg by matching "chef client " string with $_.Name
  $chef_pkg = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name.contains("Chef Client") }

  # Uninstall chef_pkg
  $result = $chef_pkg.Uninstall()
  echo $result

  # clean up config files and install folder
  if (Test-Path $bootstrapDirectory) {
    Remove-Item -Recurse -Force $bootstrapDirectory
  }
  if (Test-Path $chefInstallDirectory) {
    Remove-Item -Recurse -Force $chefInstallDirectory
  }

  Write-ChefStatus "uninstalling-chef" "success" "Uninstalled Chef"
}
Else
{
  echo "Not tried to uninstall, as the update process is running"
  Update-ChefExtensionRegistry "X"
  Write-ChefStatus "updating-chef-extension" "transitioning" "Skipping Uninstall"
}