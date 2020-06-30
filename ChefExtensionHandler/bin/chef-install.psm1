
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
  gem install "$chefExtensionRoot\\gems\\*.gem" --no-document
  Write-Host("[$(Get-Date)] Installed Azure-Chef-Extension gem successfully")
}

function Chef-GetExtensionRoot {
  $chefExtensionRoot = [System.IO.Path]::GetFullPath("$scriptDir\\..")
  $chefExtensionRoot
}

function Get-ChefPackage {
  Get-WmiObject -Class Win32_Product | where -Property Name -CLike "Chef *Client*"
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

  while (-not $completed) {
    echo "Checking Chef Client ..."
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
      ## Get msi url from config file.
      $chef_package_url = Get-PublicSettings-From-Config-Json "chef_package_url" $powershellVersion
      ## Get locally downloaded msi path string from config file.
      $chef_downloaded_package = Get-PublicSettings-From-Config-Json "chef_package_path" $powershellVersion
      $daemon = Get-PublicSettings-From-Config-Json "daemon"  $powershellVersion
      if ( $daemon -eq "none" ) {
        $daemon = "auto"
      }
      if (-Not $daemon) {
        $daemon = "service"
      }
      if (-Not $chef_pkg -and -Not $chef_downloaded_package -and -Not $chef_package_url) {
        $chef_package_version = Get-PublicSettings-From-Config-Json "bootstrap_version" $powershellVersion
        $chef_package_channel = Get-PublicSettings-From-Config-Json "bootstrap_channel" $powershellVersion

        if (-Not $chef_package_version) {
          $chef_package_version = "15" # Until Chef-16 is Verified
        }
        if (-Not $chef_package_channel) {
          $chef_package_channel = "stable"
        }

        iex (new-object net.webclient).downloadstring('https://omnitruck.chef.io/install.ps1');install -daemon $daemon -version $chef_package_version -channel $chef_package_channel
      } elseif ( -Not $chef_pkg -and $chef_downloaded_package ) {
        Install-ChefMsi $chef_downloaded_package $daemon
      } elseif ( -Not $chef_pkg -and $chef_package_url ) {
        $chef_downloaded_package = "$env:TEMP\chef-client.msi"
        Invoke-WebRequest -Uri $chef_package_url -OutFile $chef_downloaded_package
        Install-ChefMsi $chef_downloaded_package $daemon
        Remove-Item $chef_downloaded_package -force
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

Export-ModuleMember -Function Install-ChefClient
