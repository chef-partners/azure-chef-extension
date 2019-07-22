
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
    echo "Downloading Chef Client ..."
    Try {
      ## Get chef_pkg by matching "chef client" string with $_.Name
      $chef_pkg = Get-ChefPackage
      ## Get locally downloaded msi path string from config file.
      $msi_path = Get-PublicSettings-From-Config-Json "msi_path" $powershellVersion
      $daemon = Get-PublicSettings-From-Config-Json "daemon"  $powershellVersion
      if ( $daemon -eq "none" ) {
        $daemon = "auto"
      }
      if (-Not $daemon) {
        $daemon = "service"
      }
      if (-Not $chef_pkg -and -Not $msi_path ) {
        $chef_package_version = Get-PublicSettings-From-Config-Json "bootstrap_version" $powershellVersion
        $chef_package_channel = Get-PublicSettings-From-Config-Json "bootstrap_channel" $powershellVersion

        if (-Not $chef_package_version) {
          $chef_package_version = "14" # Until Chef-15 is Verified
        }
        if (-Not $chef_package_channel) {
          $chef_package_channel = "stable"
        }

        iex (new-object net.webclient).downloadstring('https://omnitruck.chef.io/install.ps1');install -daemon $daemon -version $chef_package_version -channel $chef_package_channel
      } ElseIf ( -Not $chef_pkg -and $msi_path ) {
        Install-ChefMsi $msi_path $daemon
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

Function Install-ChefMsi($msi, $addlocal) {
  if ($addlocal -eq "service") {
    $p = Start-Process -FilePath "msiexec.exe" -ArgumentList "/qn /i $msi ADDLOCAL=`"ChefClientFeature,ChefServiceFeature`"" -Passthru -Wait -NoNewWindow
  }
  ElseIf ($addlocal -eq "task") {
    $p = Start-Process -FilePath "msiexec.exe" -ArgumentList "/qn /i $msi ADDLOCAL=`"ChefClientFeature,ChefSchTaskFeature`"" -Passthru -Wait -NoNewWindow
  }
  ElseIf ($addlocal -eq "auto") {
    $p = Start-Process -FilePath "msiexec.exe" -ArgumentList "/qn /i $msi" -Passthru -Wait -NoNewWindow
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

function Get-SharedHelper {
  $chefExtensionRoot = Chef-GetExtensionRoot
  "$chefExtensionRoot\\bin\\shared.ps1"
}

Export-ModuleMember -Function Install-ChefClient
