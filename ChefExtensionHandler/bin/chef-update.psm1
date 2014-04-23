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

function Get-BootstrapDirectory {
  "C:\\chef"
}

function Get-TempBackupDir {
  $env:temp + "\\chef_backup"
}

function Update-ChefClient {
  # Import Chef Install and Chef Uninstall PS modules
  Import-Module "$(Chef-GetExtensionRoot)\\bin\\chef-install.psm1"
  Import-Module "$(Chef-GetExtensionRoot)\\bin\\chef-uninstall.psm1"

  # Source the shared PS
  . $(Get-SharedHelper)

  # powershell has in built cmdlets: ConvertFrom-Json and ConvertTo-Json which are supported above PS v 3.0
  # so the hack - use ruby json parsing for versions lower than 3.0
  if ( $(Get-PowershellVersion) -ge 3 ) {
    $json_handlerSettingsFileName, $json_handlerSettings, $json_protectedSettings,  $json_protectedSettingsCertThumbprint, $json_client_rb , $json_runlist, $json_chefLogFolder, $json_statusFolder, $json_heartbeatFile = Read-JsonFile
  } else {
    $json_handlerSettingsFileName, $json_handlerSettings, $json_protectedSettings,  $json_protectedSettingsCertThumbprint, $json_client_rb , $json_runlist, $json_chefLogFolder, $json_statusFolder, $json_heartbeatFile = Read-JsonFileUsingRuby
  }

  Try
  {
    echo "Running update process"

    $bootstrapDirectory = Get-BootstrapDirectory
    $backupLocation = Get-TempBackupDir

    # Save chef configuration.
    Copy-Item $bootstrapDirectory $backupLocation -recurse
    echo "Configuration saved to $backupLocation"

    # uninstall chef. this will work since the uninstall script is idempotent.
    echo "Calling Uninstall-ChefClient from $scriptDir\chef-uninstall.psm1"
    Uninstall-ChefClient
    echo "Uninstall completed"

    # Restore Chef Configuration
    Copy-Item $backupLocation $bootstrapDirectory -recurse

    # install new version of chef extension
    echo "Calling Install-ChefClient from $scriptDir\chef-install.psm1 on new version"
    Install-ChefClient
    echo "Install completed"

    # we dont want GA to run uninstall again, after this update.ps1 completes.
    # we pass this message to uninstall script through windows registry
    echo "Updating chef registry to 'updated'"
    Update-ChefExtensionRegistry "updated"
    echo "Updated chef registry"
  }
  Catch
  {
    $ErrorMessage = $_.Exception.Message
    Write-ChefStatus "updating-chef-extension" "error" "$ErrorMessage"
    # log to CommandExecution log:
    echo "Error running update: $ErrorMessage"
  }
}

Export-ModuleMember -Function Update-ChefClient
