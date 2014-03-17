
$chefExtensionRoot = ("{0}{1}" -f (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition), "\..")
$sequenceNumber = getHandlerSettings.Split(".")[0]

# Returns a json object from json file
function readJsonFromFile
{
  (Get-Content $args[0]) -join "`n" | ConvertFrom-Json
}

# returns the handler settings read from the latest settings file
function getHandlerSettings
{
  $latestSettingFile = (Get-ChildItem "$chefExtensionRoot\RuntimeSettings" -Filter *.settings | Sort-Object Name -descending | Select-Object -First 1 ).Name
  $runtimeSettingsJson = readJsonFromFile $chefExtensionRoot"\RuntimeSettings\$latestSettingFile"
  $runtimeSettingsJson.runtimeSettings[0].handlerSettings
}

# returns the machine os version
function getMachineOS
{

  $winMajor = [System.Environment]::OSVersion.Version.Major
  $winMinor = [System.Environment]::OSVersion.Version.Minor
  $winBuild = [System.Environment]::OSVersion.Version.Build

  echo "Detected Windows Version $winMajor.$winMinor Build $winBuild"

  $latestOSVersionMajor = 6
  $latestOSVersionMinor = 3

  $version = $null
  $machineOS =$null

  if ($winMajor -gt $latestOSVersionMajor) {
    $version = "VersionUnknown"
  } elseif ($winMajor -eq $latestOSVersionMajor) {
    if ($winMinor -gt $latestOSVersionMinor) {
      $version = "VersionUnknown"
    } else {
      $version = "Version$winMajor.$winMinor"
    }
  } else {
    $version = "Version$winMajor.$winMinor"
  }

  switch ($version)
  {
    "VersionUnknown" {
      # If this is an unknown version of windows set the default
      $machineOS ="2008r2"
      echo "Warning: Unknown version of Windows, assuming default of Windows $machineOS"
    }

    "Version6.0" {
      $machineOS = "2008"
    }

    "Version5.2" {
      $machineOS = "2003r2"
    }

    "Version6.1" {
      $machineOS="2008r2"
    }

    { ($version -eq "Version6.2") -or ($version -eq "Version6.3") } {
      $machineOS="2012"
    }
  }

  $machineOS
}

# returns the machine architecture
function getMachineArch
{
  $machineArch = $env:PROCESSOR_ARCHITECTURE
  if ($machineArch -eq "x86") {
    $machineArch = "i686"
  } elseif ($machineArch -eq "AMD64") {
    $machineArch = "x86_64"
  } else {
    # If this is an unknown architecture set the default
    $machineArch = "i686"
  }

  $machineArch
}

# write status to file
function Write-Status operation, status, message
{
  $statusFile = (readJsonFromFile $chefExtensionRoot"\HandlerEnvironment.json").handlerEnvironment.statusFolder"\"$sequenceNumber".status"
  echo "Writing status to file $statusFile"
  $timestampUTC
  @{"version":"1",
      "timestampUTC":"$timestampUTC",
      "status":
        {"name":"Chef Handler Extension",
        "operation":"$operation",
        "configurationAppliedTime":null,
        "status":"$status",
        "code":0,
        "message":null,
        "formattedMessage":
          {"lang":"en",
          "message":"$message"
          },
        "substatus":null
        }
      } | ConvertTo-Json
}

# write heartbeat
function Write-Heartbeat
{

}