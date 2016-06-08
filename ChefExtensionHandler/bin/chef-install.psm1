
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

function Install-ChefClient {
  $retries = 3
  $retrycount = 0
  $completed = $false

  while (-not $completed) {
    echo "Downloading Chef Client ..."
    Try {
      iex (new-object net.webclient).downloadstring('https://omnitruck.chef.io/install.ps1');install
      $completed = $true
    }
    Catch [System.Management.Automation.RuntimeException] {
      ## this catch is for the get-filehash command not found exception (which is of type RuntimeException) raised on powershell version 3.0 or lesser ##
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
        echo "Chef Client package download failed. Retrying..."
        $retrycount++
      }
    }
  }
  $env:Path = "C:\\opscode\\chef\\bin;C:\\opscode\\chef\\embedded\\bin;" + $env:Path
  $chefExtensionRoot = Chef-GetExtensionRoot
  Install-AzureChefExtensionGem $chefExtensionRoot
}

Export-ModuleMember -Function Install-ChefClient
