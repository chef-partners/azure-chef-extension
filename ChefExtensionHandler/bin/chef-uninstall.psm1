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
  Write-Host("[$(Get-Date)] Uninstalling chef service...")
  # uninstall does both disable and remove the service
  $result = chef-service-manager -a uninstall
  Write-Host("[$(Get-Date)] $result")
}

function Uninstall-AzureChefExtensionGem {
  Write-Host("[$(Get-Date)] Uninstalling Azure-Chef-Extension gem...")
  # Uninstall the custom gem
  $result = gem uninstall -Ix azure-chef-extension
  Write-Host("[$(Get-Date)] $result")
}

function Get-ChefInstallDirectory {
  "C:\\opscode"
}

function Get-ChefPackage {
  Get-WmiObject -Class Win32_Product | Where-Object { $_.Name.contains("Chef Client") }
}

function Uninstall-ChefClientPackage {
  param([boolean]$calledFromUpdate = $False)
  $bootstrapDirectory = Get-BootstrapDirectory
  $chefInstallDirectory = Get-ChefInstallDirectory

  # Actual uninstall functionality
  # Get chef_pkg by matching "chef client " string with $_.Name
  $chef_pkg = Get-ChefPackage

  Write-Host("[$(Get-Date)] Removing chef client and configuration files")
  # Uninstall chef_pkg
  $result = $chef_pkg.Uninstall()
  Write-Host("[$(Get-Date)] $result")

  $powershellVersion = Get-PowershellVersion

  if ($powershellVersion -ge 3) {
    if ($calledFromUpdate) {
      $json_handlerSettings = Get-PrevoiusVersionHandlerSettings
    } else {
      $json_handlerSettings = Get-HandlerSettings
    }

    $deleteChefConfig = $json_handlerSettings.publicSettings.deleteChefConfig
  } else {
    $deleteChefConfig = Get-deleteChefConfigSetting
  }

  # clean up config files and install folder only if deleteChefConfig is true
  if ((Test-Path $bootstrapDirectory) -And ($deleteChefConfig -eq "true")) {
    Remove-Item -Recurse -Force $bootstrapDirectory
  }

  if (Test-Path $chefInstallDirectory) {
    Remove-Item -Recurse -Force $chefInstallDirectory
  }
}

function Uninstall-ChefClient {
  param([boolean]$calledFromUpdate = $False)
  trap [Exception] {echo $_.Exception.Message;exit 1}

  $env:Path += ";C:\opscode\chef\bin;C:\opscode\chef\embedded\bin"

  # Source the shared PS
  . $(Get-SharedHelper)

  # powershell has in built cmdlets: ConvertFrom-Json and ConvertTo-Json which are supported above PS v 3.0
  # so the hack - use ruby json parsing for versions lower than 3.0
  if ( $(Get-PowershellVersion) -ge 3 ) {
    $logStatus = $True
    $json_handlerSettingsFileName, $json_statusFolder = Read-JsonFile $calledFromUpdate
  } else {
    $logStatus = $False
  }

  if (!(Test-ChefExtensionRegistry)) {
    if ($logStatus) {  Write-ChefStatus "uninstalling-chef" "transitioning" "Uninstalling Chef" }

    Uninstall-ChefService

    Uninstall-AzureChefExtensionGem

    Uninstall-ChefClientPackage $calledFromUpdate

    if ($logStatus) { Write-ChefStatus "uninstalling-chef" "success" "Uninstalled Chef" }
  } else {
    Write-Host("[$(Get-Date)] Not tried to uninstall, as the update process is running")
    Update-ChefExtensionRegistry "X"
    if ($logStatus) { Write-ChefStatus "updating-chef-extension" "transitioning" "Skipping Uninstall" }
  }
}

Export-ModuleMember -Function Uninstall-ChefClient
