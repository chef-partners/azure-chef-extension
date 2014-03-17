<#
Author:: Mukta Aphale (mukta.aphale@clogeny.com)
Copyright:: Copyright (c) 2014 Opscode, Inc.

// install chef-client with /i switch
// Actions: (do what windows bootstrap template)
//    - install chef-client
//    - create client.rb, validation.pem
//    - run chef-client
//      (run will need to pick up runlist from handlerSettings)

#>

function Chef-Get-ScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

$scriptDir = Chef-Get-ScriptDirectory

# Source the shared PS
$chefExtensionRoot = [System.IO.Path]::GetFullPath("$scriptDir\..")
. $chefExtensionRoot\bin\shared.ps1

$machineOS = getMachineOS
$machineArch = getMachineArch

# In current version we pick up the latest msi from within zip package.

$chefClientMsiLogPath = "$env:temp\chef-client-msi806.log"

if (Test-Path $chefClientMsiLogPath) {
  echo "Archiving previous chef-client msi log."
  mv $chefClientMsiLogPath "$chefClientMsiLogPath.$(get-date -f yyyyMMddhhmmss)"
}

$localDestinationMsiPath = [System.IO.Path]::GetFullPath("$chefExtensionRoot\installer\chef-client-latest.msi")
echo "Installing chef"
Start-Process -FilePath "msiexec.exe" -ArgumentList "/qn /log $chefClientMsiLogPath /i $localDestinationMsiPath" -Wait -Passthru

# Install the custom gem
gem install "$chefExtensionRoot\gems\*.gem" --no-ri --no-rdoc

# Add scriptDir to path so azure chef-client is picked up henceforth
Chef-Add-To-Path $scriptDir
