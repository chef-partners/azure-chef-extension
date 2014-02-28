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

$handlerSettings = getHandlerSettings

$bootstrapDirectory="C:\\chef"
echo "Checking for existing directory $bootstrapDirectory"
if ( !(Test-Path $bootstrapDirectory) ) {
  echo "Existing directory not found, creating."
  mkdir $bootstrapDirectory
} else {
  echo "Existing directory found, skipping creation."
}

$machineOS = getMachineOS
$machineArch = getMachineArch
$remoteSourceMsiUrl="https://www.opscode.com/chef/download?p=windows&pv=$machineOS&m=$machineArch"
if ($handlerSettings.publicSettings.chefClientVersion)
{
  $version = $handlerSettings.publicSettings.chefClientVersion
  $remoteSourceMsiUrl = "$remoteSourceMsiUrl&v=$version"
}

$localDestinationMsiPath = "$env:temp\chef-client-latest.msi"
$chefClientMsiLogPath = "$env:temp\chef-client-msi806.log"

echo "Checking for existing downloaded package at $localDestinationMsiPath"
if (Test-Path $localDestinationMsiPath) {
  echo "Found existing downloaded package, deleting."
  Remove-Item -Recurse -Force $localDestinationMsiPath
  # Handle above delete failure
}

if (Test-Path $chefClientMsiLogPath) {
  echo "Archiving previous chef-client msi log."
  mv $chefClientMsiLogPath "$chefClientMsiLogPath.$(get-date -f yyyyMMddhhmmss)"
}

$webClient = New-Object System.Net.WebClient
$webClient.DownloadFile($remoteSourceMsiUrl, $localDestinationMsiPath)
# Handle download failure

echo "Installing chef"
msiexec /qn /log $chefClientMsiLogPath /i $localDestinationMsiPath

# Write validation key
$handlerSettings.protectedSettings.validation_key | Out-File -filePath $bootstrapDirectory\validation.pem  -encoding "Default"

echo "Created validation.pem"

# Write client.rb
$chefServerUrl = $handlerSettings.publicSettings.chefServerUrl
$chefOrgName = $handlerSettings.publicSettings.chefOrgName
$hostName = hostname

@"
log_level    :info
log_location    STDOUT

chef_server_url    "$chefServerUrl/$chefOrgName"
validation_client_name    "$chefOrgName-validator"
client_key    "$bootstrapDirectory/client.pem"
validation_key    "$bootstrapDirectory/validation.pem"

node_name    "$hostName"
"@ | Out-File -filePath $bootstrapDirectory\client.rb -encoding "Default"

echo "Created client.rb..."

# json
$runList = $handlerSettings.publicSettings.runList
@"
{
  "run_list": [$runlist]
}
"@ | Out-File -filePath $bootstrapDirectory\first-boot.json -encoding "Default"
echo "created first-boot.json"

# set path
$env:Path += ";C:\opscode\chef\bin;C:\opscode\chef\embedded\bin"

# run chef-client
echo "Running chef client"
chef-client -c $bootstrapDirectory\client.rb -j $bootstrapDirectory\first-boot.json -E _default