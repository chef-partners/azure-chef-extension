
function Chef-Get-ScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

$scriptDir = Chef-Get-ScriptDirectory

$chefExtensionRoot = [System.IO.Path]::GetFullPath("$scriptDir\\..")

# Returns a json object from json file
function readJsonFromFile
{
  (Get-Content $args[0]) -join "`n" | ConvertFrom-Json
}

function Get-HandlerSettingsFileName
{
  (Get-ChildItem "$chefExtensionRoot\\RuntimeSettings" -Filter *.settings | Sort-Object Name -descending | Select-Object -First 1 ).Name
}

function Get-HandlerSettingsFilePath {
  $latestSettingFile = Get-HandlerSettingsFileName
  $fileName = "$chefExtensionRoot\\RuntimeSettings\\$latestSettingFile"
  $fileName
}

function Get-HandlerEnvironmentFilePath {
  $fileName = "$chefExtensionRoot\\HandlerEnvironment.json"
  $fileName
}

# returns the handler settings read from the latest settings file
function Get-HandlerSettings
{
  $latestSettingFile = Get-HandlerSettingsFileName
  $runtimeSettingsJson = readJsonFromFile $chefExtensionRoot"\\RuntimeSettings\\$latestSettingFile"
  $runtimeSettingsJson.runtimeSettings[0].handlerSettings
}

# log folder path
function Get-ChefLogFolder
{
  (readJsonFromFile $chefExtensionRoot"\\HandlerEnvironment.json").handlerEnvironment.logFolder
}

# returns major os version
function getMajorOSVersion
{
  [System.Environment]::OSVersion.Version.Major
}

# returns minor os version
function getMinorOSVersion
{
  [System.Environment]::OSVersion.Version.Minor
}

# returns os build
function getOSVersionBuild
{
  [System.Environment]::OSVersion.Version.Build
}

# returns the machine os version
function getMachineOS
{

  $winMajor = getMajorOSVersion
  $winMinor = getMinorOSVersion
  $winBuild = getOSVersionBuild

  write-host "Detected Windows Version $winMajor.$winMinor Build $winBuild"

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
      write-host "Warning: Unknown version of Windows, assuming default of Windows $machineOS"
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

function Chef-Add-To-Path($folderPath)
{
  $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
  [Environment]::SetEnvironmentVariable("Path", "$folderPath;$currentPath", "Machine")
  $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
  [Environment]::SetEnvironmentVariable("Path", "$folderPath;$currentPath", "User")
  $currentPath = [Environment]::GetEnvironmentVariable("Path", "Process")
  [Environment]::SetEnvironmentVariable("Path", "$folderPath;$currentPath", "Process")
}

# write status to file N.status
function Write-ChefStatus ($operation, $statusType, $message)
{
  # the path of this file is picked up from HandlerEnvironment.json
  # the sequence is obtained from the handlerSettings file sequence
  $sequenceNumber = $json_handlerSettingsFileName.Split(".")[0]
  $statusFile = $json_statusFolder + "\\" + $sequenceNumber + ".status"

  # the status file is in json format
  $timestampUTC = (Get-Date -Format u).Replace(" ", "T")
  $formattedMessageHash = @{lang = "en-US"; message = "$message" }
  $statusHash = @{name = "Chef Extension Handler"; operation = "$operation"; status = "$statusType"; code = 0; formattedMessage = $formattedMessageHash; }

  $hash = @(@{version = "1"; timestampUTC = "$timestampUTC"; status = $statusHash})

  if ($PSVersionTable.PSVersion.Major -ge 3) {
    ConvertTo-Json -Compress $hash -Depth 4 | Out-File -filePath $statusFile
  }
  else
  {
    ruby.exe -e "require 'chef/azure/helpers/parse_json'; write_json_file '$statusFile', '$hash'"
  }
}

# write heartbeat
function Write-ChefHeartbeat
{
  $handlerSettingsFileName = Get-HandlerSettingsFileName
  $heartbeatFile = (readJsonFromFile $chefExtensionRoot"\\HandlerEnvironment.json").handlerEnvironment.heartbeatFile
}

# Decrypt protected settings
function decryptProtectedSettings($content, $thumbPrint)
{
  # load System.Security assembly
  [System.Reflection.Assembly]::LoadWithPartialName("System.Security") | out-null

  $encryptedByteArray = [Convert]::FromBase64String($content)

  $envelope =  New-Object System.Security.Cryptography.Pkcs.EnvelopedCms

  # get certificate from local machine store
  $store = new-object System.Security.Cryptography.X509Certificates.X509Store([System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
  $store.open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
  $cert = $store.Certificates | Where-Object {$_.thumbprint -eq $thumbPrint}

  $envelope.Decode($encryptedByteArray)

  $envelope.Decrypt($cert)

  $decryptedBytes = $envelope.ContentInfo.Content

  $decryptedResult = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)

  $decryptedResult
}

function Update-ChefExtensionRegistry
 {
   param (
    $Path = "HKLM:\Software\Chef\AzureExtension",
    $Name = "Status",
    [Parameter(Mandatory=$True,Position=1)]
    [string]$Value
  )

  # Create registry entry, with Status=updated
  if (Test-Path -Path $Path -PathType Container) {
    New-ItemProperty -Path $Path -Force -Name $Name -Value $Value
    echo "Registry entry exists, so just updated the value"
  }
  else {
    New-Item -Path $Path -Force -Name $Name -Value $Value
    # New-ItemProperty additionally needed below, to work for PS v 2.0
    New-ItemProperty -Path $Path -Force -Name $Name -Value $Value
    echo "Added new registry entry and updated $Name with $Value"
  }
  $temp = (Get-ItemProperty -Path $Path).$Name
  echo "Registry entry $Path after updating: $temp"
 }

 function Test-ChefExtensionRegistry
 {
   param (
      $Path = "HKLM:\Software\Chef\AzureExtension",
      $Name = "Status",
      $Value = "updated"
   )
   # checks if the entry with correct value in registry
   # if yes, it returns true
   If (Test-Path -Path $Path -PathType Container) {
     If ((Get-ItemProperty -Path $Path).$Name -eq $Value) {
       return $True
     }
     else { return $False }
   }
   else {
     return $False
   }
 }

# Reads all the json files needed and sets the fields needed
function readJsonFile
{
  $json_handlerSettingsFileName = Get-HandlerSettingsFileName
  $json_handlerSettings = Get-HandlerSettings
  $json_protectedSettings = $json_handlerSettings.protectedSettings
  $json_protectedSettingsCertThumbprint = $json_handlerSettings.protectedSettingsCertThumbprint
  $json_client_rb = $json_handlerSettings.publicSettings.client_rb
  $json_runlist = $json_handlerSettings.publicSettings.runList

  $json_chefLogFolder = Get-ChefLogFolder
  $json_statusFolder = (readJsonFromFile $chefExtensionRoot"\\HandlerEnvironment.json").handlerEnvironment.statusFolder
  $json_heartbeatFile = (readJsonFromFile $chefExtensionRoot"\\HandlerEnvironment.json").handlerEnvironment.heartbeatFile

  return  $json_handlerSettingsFileName, $json_handlerSettings, $json_protectedSettings,  $json_protectedSettingsCertThumbprint, $json_client_rb , $json_runlist, $json_chefLogFolder, $json_statusFolder, $json_heartbeatFile
}

# Reads all the json files and sets vars using ruby code
function readJsonFileUsingRuby
{
  $json_handlerSettingsFileName = Get-HandlerSettingsFilePath

  $json_handlerSettings = ruby.exe -e "require 'chef/azure/helpers/parse_json'; value_from_json_file '$json_handlerSettingsFileName', 'runtimeSettings', '0', 'handlerSettings'"

  $json_handlerProtectedSettings = ruby.exe -e "require 'chef/azure/helpers/parse_json'; value_from_json_file '$json_handlerSettingsFileName','runtimeSettings','0','handlerSettings', 'protectedSettings'"

  $json_handlerProtectedSettingsCertThumbprint = ruby.exe -e "require 'chef/azure/helpers/parse_json'; value_from_json_file '$json_handlerSettingsFileName', 'runtimeSettings', '0',  'handlerSettings' ,'protectedSettingsCertThumbprint'"

  $json_handlerPublicSettingsClient_rb = ruby.exe -e "require 'chef/azure/helpers/parse_json'; value_from_json_file '$json_handlerSettingsFileName', 'runtimeSettings', '0', 'handlerSettings', 'publicSettings', 'client_rb'"

  $json_handlerPublicSettingsRunlist = ruby.exe -e "require 'chef/azure/helpers/parse_json'; value_from_json_file '$json_handlerSettingsFileName', 'runtimeSettings', '0', 'handlerSettings', 'publicSettings', 'runList'"

  $json_handlerEnvironmentFileName = Get-HandlerEnvironmentFilePath

  $json_handlerChefLogFolder = ruby.exe -e "require 'chef/azure/helpers/parse_json'; value_from_json_file '$json_handlerEnvironmentFileName', 'handlerEnvironment', 'logFolder'"

  $json_handlerStatusFolder = ruby.exe -e "require 'chef/azure/helpers/parse_json'; value_from_json_file '$json_handlerEnvironmentFileName', 'handlerEnvironment', 'statusFolder'"

  $json_handlerHeartbeatFile = ruby.exe -e "require 'chef/azure/helpers/parse_json'; value_from_json_file '$json_handlerEnvironmentFileName', 'handlerEnvironment', 'heartbeatFile'"

  return $json_handlerSettingsFileName, $json_handlerSettings, $json_handlerProtectedSettings, $json_handlerProtectedSettingsCertThumbprint, $json_handlerPublicSettingsClient_rb, $json_handlerPublicSettingsRunlist, $json_handlerChefLogFolder, $json_handlerStatusFolder, $json_handlerHeartbeatFile

}

