# uninstall chef
# Actions:
#    - disable chef service and remove service
#    - uninstall chef

function Chef-GetScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

$scriptDir = Chef-GetScriptDirectory

function Chef-GetExtensionRoot {
  $chefExtensionRoot = [System.IO.Path]::GetFullPath("$scriptDir\\..")
  $chefExtensionRoot
}

function Get-SharedHelper {
  $chefExtensionRoot = Chef-GetExtensionRoot
  "$chefExtensionRoot\\bin\\shared.ps1"
}

function Uninstall-ChefService {
  # uninstall does both disable and remove the service
  $result = chef-service-manager -a uninstall
  echo $result
}

function Uninstall-AzureChefExtensionGem {
  # Uninstall the custom gem
  $result = gem uninstall -Ix azure-chef-extension
  echo $result
}

function Get-BootstrapDirectory {
  "C:\\chef"
}

function Get-ChefInstallDirectory {
  "C:\\opscode"
}

function Get-ChefPackage {
  Get-WmiObject -Class Win32_Product | Where-Object { $_.Name.contains("Chef Client") }
}

function Uninstall-ChefClientPackage {
  $bootstrapDirectory = Get-BootstrapDirectory
  $chefInstallDirectory = Get-ChefInstallDirectory

  # Actual uninstall functionality
  # Get chef_pkg by matching "chef client " string with $_.Name
  $chef_pkg = Get-ChefPackage

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
}

function Get-PowershellVersion {
  $PSVersionTable.PSVersion.Major
}

function Uninstall-ChefClient {
  trap [Exception] {echo $_.Exception.Message;exit 1}

  $env:Path += ";C:\opscode\chef\bin;C:\opscode\chef\embedded\bin"

  # Source the shared PS
  . $(Get-SharedHelper)

  # powershell has in built cmdlets: ConvertFrom-Json and ConvertTo-Json which are supported above PS v 3.0
  # so the hack - use ruby json parsing for versions lower than 3.0
  if ( $(Get-PowershellVersion) -ge 3 ) {
    $logStatus = $True
    $json_handlerSettingsFileName, $json_handlerSettings, $json_protectedSettings,  $json_protectedSettingsCertThumbprint, $json_client_rb , $json_runlist, $json_chefLogFolder, $json_statusFolder, $json_heartbeatFile = Read-JsonFile
  } else {
    $logStatus = $False
  }

  if (!(Test-ChefExtensionRegistry)) {
    if ($logStatus) {  Write-ChefStatus "uninstalling-chef" "transitioning" "Uninstalling Chef" }

    Uninstall-ChefService

    Uninstall-AzureChefExtensionGem

    Uninstall-ChefClientPackage

    if ($logStatus) { Write-ChefStatus "uninstalling-chef" "success" "Uninstalled Chef" }
  } else {
    echo "Not tried to uninstall, as the update process is running"
    Update-ChefExtensionRegistry "X"
    if ($logStatus) { Write-ChefStatus "updating-chef-extension" "transitioning" "Skipping Uninstall" }
  }
}

Export-ModuleMember -Function Uninstall-ChefClient
