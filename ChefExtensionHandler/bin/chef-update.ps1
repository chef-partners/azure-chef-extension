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

function Chef-Get-ScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

$scriptDir = Chef-Get-ScriptDirectory

# Source the shared PS
$chefExtensionRoot = [System.IO.Path]::GetFullPath("$scriptDir\\..")
. $chefExtensionRoot\\bin\\shared.ps1

Try
{
  Write-ChefStatus "updating-chef-extension" "transitioning" "Updating Chef Extension"
  .\chef-install.ps1
  Write-ChefExtensionRegistry
  Write-ChefStatus "updating-chef-extension" "success" "Updated Chef Extension"
}
Catch
{
  $ErrorMessage = $_.Exception.Message
  Write-ChefStatus "updating-chef-extension" "error" "$ErrorMessage"
}