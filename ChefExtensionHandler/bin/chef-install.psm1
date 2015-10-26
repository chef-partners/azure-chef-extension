
<#
// install chef-client with /i switch
// Actions: (do what windows bootstrap template)
//    - install chef-client

#>

function Chef-GetScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

$scriptDir = Chef-GetScriptDirectory

function Get-ChefClientMsiLogPath {
  # In current version we pick up the latest msi from within zip package.
  "$env:temp\\chef-client-msi806.log"
}

function Archive-ChefClientLog($chefClientMsiLogPath) {
  echo "Archiving previous chef-client msi log."
  mv $chefClientMsiLogPath "$chefClientMsiLogPath.$(get-date -f yyyyMMddhhmmss)"
}

function Run-ChefInstaller($localDestinationMsiPath, $chefClientMsiLogPath) {
  Write-Host("[$(Get-Date)] Installing chef...")
  Start-Process -FilePath "msiexec.exe" -ArgumentList "/qn /log $chefClientMsiLogPath /i $localDestinationMsiPath" -Wait -Passthru
  Write-Host("[$(Get-Date)] Chef Client Package installed successfully!")
}

function Install-AzureChefExtensionGem($chefExtensionRoot) {
  # Install the custom gem
  Write-Host("[$(Get-Date)] Installing Azure-Chef-Extension gem")
  gem install "$chefExtensionRoot\\gems\\*.gem" --no-ri --no-rdoc
  Write-Host("[$(Get-Date)] Installed Azure-Chef-Extension gem successfully")
}

function Chef-GetExtensionRoot {
  $chefExtensionRoot = [System.IO.Path]::GetFullPath("$scriptDir\\..")
  $chefExtensionRoot
}

function Get-SharedHelper {
  $chefExtensionRoot = Chef-GetExtensionRoot
  "$chefExtensionRoot\\bin\\shared.ps1"
}

function Get-LocalDestinationMsiPath {
  [System.IO.Path]::GetFullPath("$env:temp\\chef-client-latest.msi")
}

function Install-ChefClient {
  trap [Exception] {echo $_.Exception.Message;exit 1}

  # Source the shared PS
  . $(Get-SharedHelper)

  $chefExtensionRoot = Chef-GetExtensionRoot

  $chefClientMsiLogPath = Get-ChefClientMsiLogPath

  if (Test-Path $chefClientMsiLogPath) {
    Archive-ChefClientLog $chefClientMsiLogPath
  }

  Download-ChefClient

  $localDestinationMsiPath = Get-LocalDestinationMsiPath

  Run-ChefInstaller $localDestinationMsiPath $chefClientMsiLogPath

  $env:Path += ";C:\\opscode\\chef\\bin;C:\\opscode\\chef\\embedded\\bin"

  Install-AzureChefExtensionGem $chefExtensionRoot

  Copy-SettingsFile $chefExtensionRoot
}

function Copy-SettingsFile($chefExtesnsionRoot) {
  Write-Host("[$(Get-Date)] Copying settings file ...")
  $bootstrapDirectory = Get-BootstrapDirectory
  Copy-Item "$chefExtensionRoot\\RuntimeSettings\\*.settings" "$$bootstrapDirectory"
  Write-Host("[$(Get-Date)] Copied settings file ...")
}

function Download-ChefClient {
  # TODO: Add functionality to accept version for chef-client from user and update $remoteUrl accordingly
  $remoteUrl = "http://www.chef.io/chef/download?p=windows&pv=2012&m=x86_64&v=latest&prerelease=false"
  $localPath = "$env:temp\\chef-client-latest.msi"
  $webClient = new-object System.Net.WebClient
  echo "Downloading Chef Client ..."
  Try {
    $webClient.DownloadFile($remoteUrl, $localPath)
  }
  Catch{
    $ErrorMessage = $_.Exception.Message
    # log to CommandExecution log:
    echo "Error running install: $ErrorMessage"
  }
}

Export-ModuleMember -Function Install-ChefClient
