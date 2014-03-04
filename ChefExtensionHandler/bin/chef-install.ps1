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

# Source the shared PS
$chefExtensionRoot = ("{0}{1}" -f (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition), "\..")
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
msiexec /qn /log $chefClientMsiLogPath /i $localDestinationMsiPath

# set path
$env:Path += ";C:\opscode\chef\bin;C:\opscode\chef\embedded\bin"
