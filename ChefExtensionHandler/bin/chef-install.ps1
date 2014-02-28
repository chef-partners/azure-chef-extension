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

$bootstrapDirectory="C:\chef"
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

# TODO: Set the following paths dynamically
$localDestinationMsiPath = "$env:temp\chef-client-latest.msi"
$chefClientMsiLogPath = "$env:temp\chef-client-msi806.log"

echo "Checking for existing downloaded package at $localDestinationMsiPath"
if (Test-Path $localDestinationMsiPath) {
  echo "Found existing downloaded package, deleting."
  rm -rf $localDestinationMsiPath
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
echo "-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAoURVHwetS62ARjTiZvq+DSYzqR/F/23LHXukwl744FIvt9iw
YhVJQktLfc4H7rJYUUUNDe6Bh5dKsiDSgTbUDHoih+ZTAhVdOTCehTAsOvdmynlN
oL0/5aSExDSP2KZ1r+Vwd+1MFA9gtyMCrLjtT+RGKPwahJgvsWX6TZ+42FnDXda8
zKVhurdCrhLYwZYa8oHff6I8wbMJgTeE0lotNGIgoWRESG6Ll34+NffwzeP+Ks1y
Ko7Qc+EVqDvQXF8QPMHgiP1+qBOqQFJde6WCPWhnTlrZuEW/2lqSMdQQshKD7HHD
CPbAv9bwAUItW9xun2aLotr9q/xVXO8HGyQEyQIDAQABAoIBAElLX0ydFpwgnP5L
puKa76nWRQCG2lx/MCOUQIu+0mpRsDJkn7XUatlgk0z4SQ6prA4zzf0Y+3H+xwoy
dLoZi0Kod+1AN1XpE9ecS0/JVzDtpKA9hZSaruHWZikuonobHb32D6nSBhPP8WsK
1HpgCiuXWnPiMMM2z+ZWrO5+u2pImRSfN0wGvP4P2TQewvPrbEwdbVLbzlFIz0YS
pQZ/g0qpk8POBp3YN16y5SkLIXtzwDvTW79ruVuJYQqAKs2xcx5AjGTvlT6yx+UP
bFirLY3JveZO4Ge0lhmVq/0BW49ieoWsc8zrHZADXyiJ50SzcCl3id6KjuMlWFOD
apbixwECgYEAznkznRVraypYQ6/fg/8EZDJlReCujmJEhG3HwNYcwDwTSt/NkvH3
I69EuCE13p2W6KQeFJUKQni7is1FJM7IVhHDtK1tan4ioQDytSeIDpXnsRXRaf1w
R8GxWjOvBq7KYcHsdoS4hl6I2OEJcni6GdY2gm4BFFifEEZHH38sFNECgYEAx/Mo
23JHp3yCnlrnEflL8NHe4NEDuc+8n4XMLtL2vsFLdlOdCC3bseYtSUQT4zSSFaZr
gYUoe2xHuheu0yzyzaD3PQ0nci/R74Q9Yx+stJHm4zjSiU1uyDJpmteuQZ0gIoIx
4kIBQOb+yT3zLxB9lOlMv23qfJ+HLpArTHkuznkCgYAicoov7QDs8jWjpVYPOZ7L
8LSAwgmda7uutHodLBvD3sIBPfGYUJJA+97lMXVBXN1uluMF4A/EI0x2zeR5TZ6S
7YfPPxgAKmcwoW3c12mVtWDgZJl5q3TuI9ypBfJvlP3i7W28IEyA7oi6VmEzHf0+
jkSt4hiAAoEXQAJhuN/r4QKBgGxAKBmOqF5z2V+URU+E0WlipjC+2C6L2knfLSkY
i//ANHOuVvDrquqIfHITClVSy9guzjtD9SPE/pwwYDTyO8253MDP01BNtXHf/UAi
EOV9rCvOQqWVJ2n5aRUsuanKQHCOXiVpqLYTmVMoV/VeDy9Ek4l8H5wy3gQGh3qS
jRW5AoGBALJ+i7Kj0zJ4fvyCBfG6TS51uP8JEN0br6YGNw/hq5pF6Y7OeZSOi5fb
TlPSWhtGNK2RYsnLmOiusq+B0oVLDWd2VOPTiBe8WIbYUTZaTmE/zGnbR96xbXqi
XLmhm+ETuCI+3MvdLjwI2SZheMRXqNP4B7EGaqXg8LP9S914bQ3Q
-----END RSA PRIVATE KEY-----" | Out-File -filePath $bootstrapDirectory\validation.pem  -encoding "Default"

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
  "runlist": [$runlist]
}
"@ | Out-File -filePath $bootstrapDirectory\first-boot.json -encoding "Default"
echo "created first-boot.json"

# set path
$env:Path += ";C:\opscode\chef\bin;C:\opscode\chef\embedded\bin"
echo "PATH set = $env:Path"

# run chef-client
echo "Running chef client"
chef-client -c $bootstrapDirectory\client.rb -j $bootstrapDirectory\first-boot.json -E _default