
<#
// install chef-client with /i switch
// Actions: (do what windows bootstrap template)
//    - install chef-client

#>

function Chef-GetScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

$scriptDir = Chef-GetScriptDirectory

function Install-AzureChefExtensionGem($chefExtensionRoot) {
  # Install the custom gem
  Write-Host("[$(Get-Date)] Installing Azure-Chef-Extension gem")
  gem install "$chefExtensionRoot\\gems\\*.gem" --no-ri --no-rdoc
  Write-Host("[$(Get-Date)] Installed Azure-Chef-Extension gem successfully")
}

function Chef-GetExtensionRoot {
  $chefExtensionRoot = [System.IO.Path]::GetFullPath("$scriptDir\\..")
  $chefExtensionRoot
}

function Get-ChefPackage {
  Get-WmiObject -Class Win32_Product | Where-Object { $_.Name.contains("Chef Client") }
}

function Get-PublicSettings-From-Config-Json($key, $powershellVersion) {
  Try
  {
    $azure_config_file = Get-Azure-Config-Path($powershellVersion)
    $json_contents = Get-Content $azure_config_file
    $normalized_json = normalize_json($json_contents)

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

function normalize_json($json) {
  $json -Join " "
}

function Get-Azure-Config-Path($powershellVersion) {
  $chefExtensionRoot = Chef-GetExtensionRoot

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
    $config_files = get-childitem $config_folder -recurse | where {$_.extension -eq ".settings"}

    if($config_files -is [system.array]) {
      $config_file_name = $config_files[-1].Name
    }
    else {
      $config_file_name = $config_files.Name
    }

    "$config_folder\$config_file_name"
  }
  Catch
  {
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    echo "Failed to read file: $FailedItem. The error message was $ErrorMessage"
    throw "Error in Get-Azure-Config-Path. Couldn't parse the HandlerEnvironment.json file"
  }
}

function Install-ChefClient {
  # Source the shared PS
  . $(Get-SharedHelper)
  $powershellVersion = Get-PowershellVersion

  # Run PowerShell with the .NET 4 runtime if powershell version is less than 3
  if ( $powershellVersion -lt 3 ) {
    Run-Powershell-With-Dot-Net4
  }

  # Install Chef Client
  $retries = 3
  $retrycount = 0
  $completed = $false

  while (-not $completed) {
    echo "Downloading Chef Client ..."
    Try {
      ## Get chef_pkg by matching "chef client" string with $_.Name
      $chef_pkg = Get-ChefPackage
      if (-Not $chef_pkg) {
        $chef_package_version = Get-PublicSettings-From-Config-Json "bootstrap_version" $powershellVersion
        $daemon = Get-PublicSettings-From-Config-Json "daemon"  $powershellVersion

        if ( $daemon -eq "none" ) {
          $daemon = "auto"
        }
        if (-Not $chef_package_version) {
          $chef_package_version = "latest"
        }
        if (-Not $daemon) {
          $daemon = "service"
        }

        iex (new-object net.webclient).downloadstring('https://omnitruck.chef.io/install.ps1');install -daemon $daemon -version $chef_package_version
      }
      $completed = $true
    }
    Catch [System.Net.WebException] {
      ## this catch is for the WebException raised during a WebClient request while downloading the chef-client package ##
      if ($retrycount -ge $retries) {
        echo "Chef Client Downloading failed after 3 retries."
        $ErrorMessage = $_.Exception.Message
        # log to CommandExecution log:
        echo "Error running install: $ErrorMessage"
        exit 1
      } else {
        echo "Chef Client package download failed. Retrying in 20s..."
        sleep 20
        $retrycount++
      }
    }
  }
  $env:Path = "C:\\opscode\\chef\\bin;C:\\opscode\\chef\\embedded\\bin;" + $env:Path
  $chefExtensionRoot = Chef-GetExtensionRoot
  Install-AzureChefExtensionGem $chefExtensionRoot
}

function Get-SharedHelper {
  $chefExtensionRoot = Chef-GetExtensionRoot
  "$chefExtensionRoot\\bin\\shared.ps1"
}

function Get-ReloadPowershellSession {
  $chefExtensionRoot = Chef-GetExtensionRoot
  "$chefExtensionRoot\\bin\\reload_powershell_session.ps1"
}

# Run PowerShell with the .NET 4 runtime if powershell version is less than 3
# This is required because at times powershell is pointing to .NET 3.5 by default
# powershell versions less than 3 don't support functions like `ConvertFrom-Json`.
# For supporting json parsing, we need to add assembly `system.web.extensions`
# and this assembly is supported by .NET 4 version only

function Run-Powershell-With-Dot-Net4 {
  reg add hklm\software\microsoft\.netframework /v OnlyUseLatestCLR /t REG_DWORD /d 1 /f
  reg add hklm\software\wow6432node\microsoft\.netframework /v OnlyUseLatestCLR /t REG_DWORD /d 1 /f
}

Export-ModuleMember -Function Install-ChefClient
