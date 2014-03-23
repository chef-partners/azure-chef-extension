
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

function getHandlerSettingsFileName
{
  (Get-ChildItem "$chefExtensionRoot\\RuntimeSettings" -Filter *.settings | Sort-Object Name -descending | Select-Object -First 1 ).Name
}

# returns the handler settings read from the latest settings file
function getHandlerSettings
{
  $latestSettingFile = getHandlerSettingsFileName
  $runtimeSettingsJson = readJsonFromFile $chefExtensionRoot"\\RuntimeSettings\\$latestSettingFile"
  $runtimeSettingsJson.runtimeSettings[0].handlerSettings
}

# log folder path
function Get-ChefLogFolder
{
  (readJsonFromFile $chefExtensionRoot"\\HandlerEnvironment.json").handlerEnvironment.logFolder
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
      Write-ChefStatus "chef-install" "warning" "Unknown version of Windows, assuming default of Windows $machineOS"
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
  $handlerSettingsFileName = getHandlerSettingsFileName
  $sequenceNumber = $handlerSettingsFileName.Split(".")[0]
  $statusFile = (readJsonFromFile $chefExtensionRoot"\\HandlerEnvironment.json").handlerEnvironment.statusFolder + "\\" + $sequenceNumber + ".status"

  # the status file is in json format
  $timestampUTC = (Get-Date -Format u).Replace(" ", "T")
  $formattedMessageHash = @{lang = "en-US"; message = "$message" }
  $statusHash = @{name = "Chef Extension Handler"; operation = "$operation"; status = "$statusType"; code = 0; formattedMessage = $formattedMessageHash; }

  ConvertTo-Json -Compress @(@{version = "1"; timestampUTC = "$timestampUTC"; status = $statusHash}) -Depth 4 | Out-File -filePath $statusFile
}

# write heartbeat
function Write-ChefHeartbeat
{
  $handlerSettingsFileName = getHandlerSettingsFileName
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
    $Path = "HKCU:\Software\chef_extn",
    $Name = "Status",
    [Parameter(Mandatory=$True,Position=1)]
    [string]$Value
  )

  # Create registry entry, with Status=updated
  if (Test-Path -Path $Path -PathType Container) {
    New-ItemProperty -Path $Path -Force -Name $Name -Value $Value
  }
  else {
    New-Item -Path $Path -Force -Name $Name -Value $Value
  }
 }

 function Test-ChefExtensionRegistry
 {
   param (
      $Path = "HKCU:\Software\chef_extn",
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
