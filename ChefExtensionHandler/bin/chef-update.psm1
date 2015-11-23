# Reinstall with new version
#
# GA will do this:
# 1 unpack new pkg at <extn>/<new ver>/new zip
# 2 disable old version
# 3 update new version
# 4 uninstall old version
# 5 enable new version

# This script witll call install (on the new version)
# We do not want the step 4 above to uninstall this latest installation. So we keep a track of this using the Windows Registry
# This will update the registry. The uninstall script witll uninstall if the registry "Status" is not "updated"

# We cannot Write-ChefStatus from this script.

# delete .auto_update_false file if it exists
$ChkFile = "C:\chef\.auto_update_false"
$FileExists = Test-Path $ChkFile
If ($FileExists -eq $True) {
  Remove-Item $ChkFile
}

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

function Get-TempBackupDir {
  $env:temp + "\\chef_backup"
}

function Update-ChefClient {

  # Source the shared PS
  . $(Get-SharedHelper)

  $env:Path += ";C:\\opscode\\chef\\bin;C:\\opscode\\chef\\embedded\\bin"

  $powershellVersion = Get-PowershellVersion

  if ($powershellVersion -ge 3) {
    $json_handlerSettings = Get-PreviousVersionHandlerSettings
    $autoUpdateClient = $json_handlerSettings.publicSettings.autoUpdateClient
  } else {
    $autoUpdateClient = Get-autoUpdateClientSetting
  }

  Write-Host "[$(Get-Date)] AutoUpdateClient: $autoUpdateClient"
  # Auto update flag in Runtime Settings allows the user to opt for automatic chef-client update.
  # Default value is false
  if($autoUpdateClient -ne "true"){
    Write-Host "[$(Get-Date)] Auto update disabled"

    # create the auto_update_false file
    # We refer this file inside uninstall.sh, install.sh and enable.sh so that waagent doesn't update
    # even if autoUpdateClient=false.
    # Waagent itself spawns processes for uninstall, install and enable otherwise.
    New-Item c:/chef/.auto_update_false -type file

    return
  }

  # Import Chef Install and Chef Uninstall PS modules
  Import-Module "$(Chef-GetExtensionRoot)\\bin\\chef-install.psm1"
  Import-Module "$(Chef-GetExtensionRoot)\\bin\\chef-uninstall.psm1"

  Try
  {
    Write-Host "[$(Get-Date)] Running update process"

    $bootstrapDirectory = Get-BootstrapDirectory
    $backupLocation = Get-TempBackupDir
    $calledFromUpdate = $True
    # Save chef configuration.
    Copy-Item $bootstrapDirectory $backupLocation -recurse
    Write-Host "[$(Get-Date)] Configuration saved to $backupLocation"

    # uninstall chef. this will work since the uninstall script is idempotent.
    echo "Calling Uninstall-ChefClient from $scriptDir\chef-uninstall.psm1"
    Uninstall-ChefClient $calledFromUpdate
    Write-Host "[$(Get-Date)] Uninstall completed"

    # Restore Chef Configuration
    Copy-Item $backupLocation $bootstrapDirectory -recurse

    # install new version of chef extension
    echo "Calling Install-ChefClient from $scriptDir\chef-install.psm1 on new version"
    Install-ChefClient
    Write-Host "[$(Get-Date)] Install completed"

    # we dont want GA to run uninstall again, after this update.ps1 completes.
    # we pass this message to uninstall script through windows registry
    Write-Host "[$(Get-Date)] Updating chef registry to 'updated'"
    Update-ChefExtensionRegistry "updated"
    Write-Host "[$(Get-Date)] Updated chef registry"
  }
  Catch
  {
    $ErrorMessage = $_.Exception.Message
    Write-ChefStatus "updating-chef-extension" "error" "$ErrorMessage"
    # log to CommandExecution log:
    Write-Host "[$(Get-Date)] Error running update: $ErrorMessage"
  }
}

Export-ModuleMember -Function Update-ChefClient
