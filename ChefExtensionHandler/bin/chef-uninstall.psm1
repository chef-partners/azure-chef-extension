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

function Uninstall-ChefSchTask {
  Write-Host("[$(Get-Date)] Uninstalling chef scheduled task...")
  $result = schtasks /delete /tn "chef-client" /f
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

function Uninstall-ChefClient {
  param([boolean]$calledFromUpdate = $False, [string]$configFilePath)
  trap [Exception] {echo $_.Exception.Message;exit 1}

  # Source the shared PS
  . $(Get-SharedHelper)

  $env:Path = "C:\\opscode\\chef\\bin;C:\\opscode\\chef\\embedded\\bin;" + $env:Path

  $powershellVersion = Get-PowershellVersion

  # powershell has in built cmdlets: ConvertFrom-Json and ConvertTo-Json which are supported above PS v 3.0
  # so the hack - use ruby json parsing for versions lower than 3.0
  if ( $(Get-PowershellVersion) -ge 3 ) {
    $logStatus = $True
    $json_handlerSettingsFileName, $json_statusFolder = Read-JsonFile $calledFromUpdate
  } else {
    $logStatus = $False
  }

  if (!(Test-ChefExtensionRegistry)) {
    if ($logStatus) {  Write-ChefStatus "uninstalling-chef-extension" "transitioning" "Uninstalling Chef Extension" }

    $daemon = Get-PublicSettings-From-Config-Json "daemon" $powershellVersion

    if ( -Not $daemon -Or $daemon -eq "service") {
      Uninstall-ChefService
    }
    if ( $daemon -eq "task" ) {
      Uninstall-ChefSchTask
    }

    Uninstall-AzureChefExtensionGem

    if ($logStatus) { Write-ChefStatus "uninstalling-chef-extension" "success" "Uninstalled Chef Extension" }
  } else {
    Write-Host("[$(Get-Date)] Not tried to uninstall, as the update process is running")
    Update-ChefExtensionRegistry "X"
    if ($logStatus) { Write-ChefStatus "updating-chef-extension" "transitioning" "Skipping Uninstall" }
  }
}

Export-ModuleMember -Function Uninstall-ChefClient
