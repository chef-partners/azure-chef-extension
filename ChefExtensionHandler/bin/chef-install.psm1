
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
  gem install "$chefExtensionRoot\\gems\\*.gem" --local --no-document
  Write-Host("[$(Get-Date)] Installed Azure-Chef-Extension gem successfully")
}

function Chef-GetExtensionRoot {
  $chefExtensionRoot = [System.IO.Path]::GetFullPath("$scriptDir\\..")
  $chefExtensionRoot
}

function Get-ChefPackage {
  Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where -Property DisplayName -CLike "Chef *Client*"
}

function Read-Environment-Variables {
  $powershellVersion = Get-PowershellVersion
  $environment_variables = Get-PublicSettings-From-Config-Json "environment_variables"  $powershellVersion
  if ( $environment_variables ){
    Chef-SetCustomEnvVariables $environment_variables $powershellVersion
  } else {
    echo "Environment variables not passed."
  }
}

function Install-ChefClient {
  # Source the shared PS
  . $(Get-SharedHelper)
  $powershellVersion = Get-PowershellVersion
  Read-Environment-Variables
  # Install Chef Client
  $retries = 3
  $retrycount = 0
  $completed = $false

  # Disable progress bar for massive speedup on Invoke-WebRequest (particularly with Azure Blob Stores)
  $ProgressPreference = 'SilentlyContinue'

  # Allow earlier Windows (Such as Win2016) to auto-negotiate instead of pinning to TLSv1 (For Azure Blob stores with TLSv2 ensbled)
  [Net.ServicePointManager]::SecurityProtocol = "Tls12, Tls11, Tls"

  while (-not $completed) {
    echo "Checking Chef Infra Client ..."
    Try {
      ## Get chef_pkg by matching "chef client" string with $_.Name
      $chef_pkg = Get-ChefPackage
      ## Get chef_licence value from config file.
      $chef_licence_value = Get-PublicSettings-From-Config-Json "CHEF_LICENSE" $powershellVersion
      if ( $chef_licence_value )
      {
        $chef_licence_env = New-Object -TypeName System.Management.Automation.PSObject -Property @{CHEF_LICENSE=$chef_licence_value}
        Chef-SetCustomEnvVariables $chef_licence_env $powershellVersion
        Write-Host "Set CHEF_LICENSE Environment variable as" $env:CHEF_LICENSE
      }
      ## Get chef_license_key from config file and set CHEF_LICENSE_KEY for licensed downloads.
      $chef_license_key = Get-ChefLicenseKey $powershellVersion
      if ( $chef_license_key ) {
        Set-ChefLicenseKeyEnv $chef_license_key
      }
      $chef_license_bypass = Get-ChefLicenseBypass $powershellVersion
      Write-LicenseKeyStatus $chef_license_key $chef_license_bypass
      ## Get msi url from config file.
      $chef_package_url = Get-PublicSettings-From-Config-Json "chef_package_url" $powershellVersion
      ## Get locally downloaded msi path string from config file.
      $chef_downloaded_package = Get-PublicSettings-From-Config-Json "chef_package_path" $powershellVersion
      $daemon = Get-PublicSettings-From-Config-Json "daemon"  $powershellVersion
      if ( $daemon -eq "none" ) {
        $daemon = "auto"
      }
      if (-Not $daemon) {
        $daemon = "task"
      }
      if (-Not $chef_pkg -and -Not $chef_downloaded_package -and -Not $chef_package_url) {
        echo "Downloading Chef Infra Client ..."
        $chef_package_version = Get-PublicSettings-From-Config-Json "bootstrap_version" $powershellVersion
        $chef_package_channel = Get-PublicSettings-From-Config-Json "bootstrap_channel" $powershellVersion

        if (-Not $chef_package_version) {
          $chef_package_version = "latest" 
        }
        if (-Not $chef_package_channel) {
          $chef_package_channel = "stable"
        }

        # Determine product. Always pass -project explicitly — install.ps1 will default to
        # chef-ice in a future release and this keeps the extension's behaviour stable.
        $project = "chef"
        if ($chef_package_version -ne "latest") {
          $major = ($chef_package_version -split '\.')[0] -as [int]
          if ($major -ge 19) {
            if (-not $chef_license_key) {
              Write-Error "chef-ice (v>=19) requires a license key — set chef_license_key in extension settings"
              exit 1
            }
            $project = "chef-ice"
          }
        }

        iex (new-object net.webclient).downloadstring('https://chefdownload-commercial.chef.io/install.ps1')
        if ( $chef_license_key ) {
          Write-Host "Using chef_license_key for licensed commercial download"
          install -project $project -daemon $daemon -version $chef_package_version -channel $chef_package_channel -license_id $chef_license_key
        } else {
          install -project $project -daemon $daemon -version $chef_package_version -channel $chef_package_channel
        }
      } elseif ( -Not $chef_pkg -and $chef_downloaded_package ) {
        Install-ChefMsi $chef_downloaded_package $daemon
      } elseif ( -Not $chef_pkg -and $chef_package_url ) {
        # Saving .msi in TEMP folder with pattern accepted by `Invoke-WebRequest`
        $chef_downloaded_package = "$env:TEMP\chef-client.msi"
        if ($chef_package_url -Match "@."){
          $updated_url = $chef_package_url -Replace "//.*@","//xxxxxx:xxxxxx@"
          echo "Downloading Chef Infra Client package from $updated_url"
        }
        else{
          echo "Downloading Chef Infra Client package from $chef_package_url"
        }
        Invoke-WebRequest -Uri $chef_package_url -OutFile $chef_downloaded_package
        echo "Installing Chef Infra Client from path $chef_downloaded_package"
        Install-ChefMsi $chef_downloaded_package $daemon
      }
      $completed = $true
    }
    Catch [System.Net.WebException] {
      ## this catch is for the WebException raised during a WebClient request while downloading the chef-client package ##
      if ($retrycount -ge $retries) {
        echo "Chef Infra Client Downloading failed after 3 retries."
        $ErrorMessage = $_.Exception.Message
        # log to CommandExecution log:
        echo "Error running install: $ErrorMessage"
        exit 1
      } else {
        echo "Chef Infra Client package download failed. Retrying in 20s..."
        sleep 20
        $retrycount++
      }
    }
  }
  if ($project -eq "chef-ice") {
    $env:Path = "C:\hab\bin;" + $env:Path
  } else {
    $env:Path = "C:\opscode\chef\bin;C:\opscode\chef\embedded\bin;" + $env:Path
  }
  $chefExtensionRoot = Chef-GetExtensionRoot
  Install-AzureChefExtensionGem $chefExtensionRoot
}

function Get-SharedHelper {
  $chefExtensionRoot = Chef-GetExtensionRoot
  "$chefExtensionRoot\\bin\\shared.ps1"
}

Export-ModuleMember -Function Install-ChefClient
