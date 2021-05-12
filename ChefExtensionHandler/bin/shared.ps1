
function Chef-GetScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

$scriptDir = Chef-GetScriptDirectory

$chefExtensionRoot = [System.IO.Path]::GetFullPath("$scriptDir\\..")

$chefExtensionParent = [System.IO.Path]::GetFullPath("$scriptDir\\..\\..")

# Returns a json object from json file
function Read-JsonFromFile
{
  (Get-Content $args[0]) -join "`n" | ConvertFrom-Json
}

function Get-HandlerSettingsFileName
{
  param([string]$extensionDirPath = $chefExtensionRoot)
  (Get-ChildItem "$extensionDirPath\\RuntimeSettings" -Filter *.settings | Sort-Object Name -descending | Select-Object -First 1 ).Name
}

function Get-PreviousExtensionVersion
{
  (Get-ChildItem $chefExtensionParent | Sort-Object Name -descending | Select-Object -Index 1 ).Name
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
function Get-HandlerSettings {
  $latestSettingFile = Get-HandlerSettingsFileName
  $runtimeSettingsJson = Read-JsonFromFile $chefExtensionRoot"\\RuntimeSettings\\$latestSettingFile"
  $runtimeSettingsJson.runtimeSettings[0].handlerSettings
}

# returns the Previous Extension Versions HandlerSettings read from the latest settings file
function Get-PreviousVersionHandlerSettings {
  $extensionPreviousVersion = Get-PreviousExtensionVersion
  $latestSettingFile = Get-HandlerSettingsFileName "$chefExtensionParent\\$extensionPreviousVersion"
  $runtimeSettingsJson = Read-JsonFromFile "$chefExtensionParent\\$extensionPreviousVersion\\RuntimeSettings\\$latestSettingFile"
  $runtimeSettingsJson.runtimeSettings[0].handlerSettings
}

function Get-BootstrapDirectory {
  "C:\\chef"
}

function Chef-AddToPath($folderPath)
{
  $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
  [Environment]::SetEnvironmentVariable("Path", "$folderPath;$currentPath", "Machine")
  $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
  [Environment]::SetEnvironmentVariable("Path", "$folderPath;$currentPath", "User")
  $currentPath = [Environment]::GetEnvironmentVariable("Path", "Process")
  [Environment]::SetEnvironmentVariable("Path", "$folderPath;$currentPath", "Process")
}

function Chef-SetCustomEnvVariables($envHash, $powershellVersion)
{
  if ( $powershellVersion -ge 3 ) {
    $props=Get-Member -InputObject $envHash -MemberType NoteProperty
    foreach($prop in $props) {
      $propValue=$envHash | Select-Object -ExpandProperty $prop.Name
      if (-not (Test-Path Env:$prop.Name)){
        [Environment]::SetEnvironmentVariable($prop.Name, $propValue, "Machine")
        [Environment]::SetEnvironmentVariable($prop.Name, $propValue, "User")
        [Environment]::SetEnvironmentVariable($prop.Name, $propValue, "Process")
      }
    }
  } else {
    foreach($prop in $envHash.GetEnumerator()) {
      [Environment]::SetEnvironmentVariable($prop.Key, $prop.Value, "Machine")
      [Environment]::SetEnvironmentVariable($prop.Key, $prop.Value, "User")
      [Environment]::SetEnvironmentVariable($prop.Key, $prop.Value, "Process")
    }
  }
}

function Get-PowershellVersion {
  if(!$powershellVersion)
  {
      $global:powershellVersion = $PSVersionTable.PSVersion.Major
  }
  $powershellVersion
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

  if ( $(Get-PowershellVersion) -ge 3) {
    ConvertTo-Json -Compress $hash -Depth 4 | Out-File -filePath $statusFile
  }
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
  } else {
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
    } else { return $False }
  } else {
    return $False
  }
}

function Get-HandlerEnvironment {
  (Read-JsonFromFile $chefExtensionRoot"\\HandlerEnvironment.json").handlerEnvironment
}

# Reads all the json files needed and sets the fields needed
function Read-JsonFile
{
  param([boolean]$calledFromUpdate = $False)
  if ($calledFromUpdate) {
    $extensionPreviousVersion = Get-PreviousExtensionVersion
    $json_handlerSettingsFileName = Get-HandlerSettingsFileName "$chefExtensionParent\\$extensionPreviousVersion"
  }else {
    $json_handlerSettingsFileName = Get-HandlerSettingsFileName
  }

  $json_handlerEnvironment = Get-HandlerEnvironment
  $json_statusFolder = $json_handlerEnvironment.statusFolder

  return  $json_handlerSettingsFileName, $json_statusFolder
}

function Get-JsonValueUsingRuby($file) {
  $keys = $args -join "','"
  ruby.exe -e "require 'chef/azure/helpers/parse_json'; value_from_json_file_for_ps '$file', '$keys'"
}

# Reads all the json files and sets vars using ruby code
function Read-JsonFileUsingRuby
{
  $json_handlerSettingsFileName = Get-HandlerSettingsFilePath
  $json_handlerEnvironmentFileName = Get-HandlerEnvironmentFilePath
  $json_handlerStatusFolder = Get-JsonValueUsingRuby $json_handlerEnvironmentFileName "handlerEnvironment" "statusFolder"

  return $json_handlerSettingsFileName, $json_handlerStatusFolder
}

# Get the auto update setting for powershell 2
function Get-autoUpdateClientSetting{
  $extensionPreviousVersion = Get-PreviousExtensionVersion
  $latestSettingFile = Get-HandlerSettingsFileName "$chefExtensionParent\\$extensionPreviousVersion"

  Get-JsonValueUsingRuby "$chefExtensionParent\\$extensionPreviousVersion\\RuntimeSettings\\$latestSettingFile" "runtimeSettings" 0 "handlerSettings" "publicSettings" "autoUpdateClient"
}

function Get-PublicSettings-From-Config-Json($key, $powershellVersion) {
  Try
  {
    if(!$normalized_json)
    {
      $azure_config_file = Get-Azure-Config-Path($powershellVersion)
      $json_contents = Get-Content $azure_config_file
      $global:normalized_json = normalize_json($json_contents)
    }
    if ( $powershellVersion -ge 3 ) {
      $value = ($normalized_json | ConvertFrom-Json | Select -expand runtimeSettings | Select -expand handlerSettings | Select -expand publicSettings).$key
    }
    else {
      $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
      $value = $ser.DeserializeObject($normalized_json).runtimeSettings[0].handlerSettings.publicSettings.$key
    }
    $value
  }
  Catch
  {
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    echo "Failed to read file: $FailedItem. The error message was $ErrorMessage"
    throw "Error in Get-PublicSettings-From-Config-Json. Couldn't parse $azure_config_file"
  }
}

Function Install-ChefMsi($msi, $addlocal) {
  $msiLogName = "C:\WindowsAzure\Logs\ChefMsiInstaller-" + $(Get-Date -Format "yyyy-mm-dd-HH.mm.ss") + ".log"
  Write-Host "MSI log file will be written to $msiLogName"
  if ($addlocal -eq "service") {
    $p = Start-Process -FilePath "msiexec.exe" -ArgumentList "/qn /l*v $msiLogName /i $msi ADDLOCAL=`"ChefClientFeature,ChefServiceFeature`"" -Passthru -Wait -NoNewWindow
  }
  ElseIf ($addlocal -eq "task") {
    $p = Start-Process -FilePath "msiexec.exe" -ArgumentList "/qn /l*v $msiLogName /i $msi ADDLOCAL=`"ChefClientFeature,ChefSchTaskFeature`"" -Passthru -Wait -NoNewWindow
  }
  ElseIf ($addlocal -eq "auto") {
    $p = Start-Process -FilePath "msiexec.exe" -ArgumentList "/qn /l*v $msiLogName /i $msi" -Passthru -Wait -NoNewWindow
  }

  $p.WaitForExit()
  if ($p.ExitCode -eq 1618) {
    Write-Host "$((Get-Date).ToString()) - Another msi install is in progress (exit code 1618), retrying ($($installAttempts))..."
    return $false
  } elseif ($p.ExitCode -ne 0) {
    throw "msiexec was not successful. Received exit code $($p.ExitCode)"
  }
  return $true
}

function normalize_json($json) {
  $json -Join " "
}

function Get-Azure-Config-Path($powershellVersion) {
  Try
  {
    # Reading chef_extension_root/HandlerEnvironment.json file
    $handler_file = "$chefExtensionRoot\\HandlerEnvironment.json"

    if ( $powershellVersion -ge 3 ) {
      $config_folder = (((Get-Content $handler_file) | ConvertFrom-Json)[0] | Select -expand handlerEnvironment).configFolder
    }
    else {
      add-type -assembly system.web.extensions
      $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
      $config_folder = ($ser.DeserializeObject($(Get-Content $handler_file)))[0].handlerEnvironment.configFolder
    }

    # Get the last .settings file
    $config_file_name = Get-Lastest-Settings-File($config_folder)

    $azure_config_file = "$config_folder\$config_file_name"
    $config_file_is_a_folder = (Get-Item $azure_config_file) -is [System.IO.DirectoryInfo]

    # In case of update, the n.settings file doesn't exists initially in the
    # folder of the new extension. Hence using the n.settings file copied into
    # the C:\Chef folder during enable
    if ( $config_file_is_a_folder ) {
      Write-Host "n.settings file doesn't exist in the extension folder. Reading from C:\chef."
      $config_folder = "C:\Chef"
      $config_file_name = Get-Lastest-Settings-File($config_folder)
      $azure_config_file = "$config_folder\$config_file_name"
    }
    return $azure_config_file
  }
  Catch
  {
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    echo "Failed to read file: $FailedItem. The error message was $ErrorMessage"
    throw "Error in Get-Azure-Config-Path. Couldn't parse the HandlerEnvironment.json file"
  }
}

function Get-Lastest-Settings-File($config_folder) {
  $config_files = get-childitem $config_folder -recurse | where {$_.extension -eq ".settings"}

  if($config_files -is [system.array]) {
    $config_file_name = $config_files[-1].Name
  }
  else {
    $config_file_name = $config_files.Name
  }
  return $config_file_name
}

# This method is called separetely from enable.cmd before calling Install-ChefClient
# Sourcing the script again refreshes the powershell console and the changes
# of registry key become available
function Run-Powershell2-With-Dot-Net4 {
  $powershellVersion = Get-PowershellVersion

  if ( $powershellVersion -lt 3 ) {
    reg add hklm\software\microsoft\.netframework /v OnlyUseLatestCLR /t REG_DWORD /d 1 /f
    reg add hklm\software\wow6432node\microsoft\.netframework /v OnlyUseLatestCLR /t REG_DWORD /d 1 /f
  }
}
