
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
  # chef-ice (Habitat) fallback: gem lives under C:\hab\pkgs\..., not the
  # omnibus location this script normally relies on being on PATH already.
  if (-not (Get-Command gem -ErrorAction SilentlyContinue)) {
    $habRubyBin = Get-ChildItem -Path "C:\hab\pkgs\core\ruby*\*\*\bin\gem.cmd" -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1 | ForEach-Object { Split-Path $_.FullName }
    if ($habRubyBin) { $env:Path = "$habRubyBin;$env:Path" }
  }
  gem install "$chefExtensionRoot\\gems\\*.gem" --local --no-document
  Write-Host("[$(Get-Date)] Installed Azure-Chef-Extension gem successfully")
}

function Chef-GetExtensionRoot {
  $chefExtensionRoot = [System.IO.Path]::GetFullPath("$scriptDir\\..")
  $chefExtensionRoot
}

function Get-ChefPackage {
  # chef-ice registers as "Chef Infra (air-gapped) - chef-ice" (no "Client" in the
  # name), so it never matched the omnibus-only pattern below. Without this,
  # chef-ice is never detected as already installed and every re-run of
  # Install-ChefClient attempts a fresh MSI install over the existing one,
  # colliding with the already-created product/account (MSI Error 1316).
  Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -CLike "Chef *Client*" -or $_.DisplayName -CLike "Chef Infra*chef-ice*" }
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
      ## Resolve requested version/product *before* checking what's already
      ## installed, so an older Chef Client already on the box (e.g. baked
      ## into the image) doesn't cause a newer requested bootstrap_version
      ## to be silently ignored.
      $chef_package_version = Get-PublicSettings-From-Config-Json "bootstrap_version" $powershellVersion
      if (-Not $chef_package_version) {
        $chef_package_version = "latest"
      }
      $requested_major = $null
      if ($chef_package_version -ne "latest") {
        $requested_major = ($chef_package_version -split '\.')[0] -as [int]
      }
      ## Get chef_pkg by matching "chef client" string with $_.Name, and
      ## matching the requested major version (if one was requested) so a
      ## stale install of a different major version doesn't short-circuit
      ## the download below.
      $chef_pkg = Get-ChefPackage | Where-Object {
        if ($null -eq $requested_major) { return $true }
        $installed_major = ($_.DisplayVersion -split '\.')[0] -as [int]
        $installed_major -eq $requested_major
      }
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
      $daemon_setting = Get-PublicSettings-From-Config-Json "daemon"  $powershellVersion
      if ( $daemon_setting -eq "none" ) {
        $daemon_setting = "auto"
      }
      $daemon = $daemon_setting
      if (-Not $daemon) {
        $daemon = "task"
      }
      if (-Not $chef_pkg -and -Not $chef_downloaded_package -and -Not $chef_package_url) {
        echo "Downloading Chef Infra Client ..."
        $chef_package_channel = Get-PublicSettings-From-Config-Json "bootstrap_channel" $powershellVersion
        if (-Not $chef_package_channel) {
          $chef_package_channel = "stable"
        }

        # Determine product. Always pass -project explicitly - install.ps1 will default to
        # chef-ice in a future release and this keeps the extension's behaviour stable.
        $project = "chef"
        if ($chef_package_version -ne "latest") {
          $major = $requested_major
          if ($major -ge 19) {
            if (-not $chef_license_key) {
              Write-Error "chef-ice (v>=19) requires a license key - set chef_license_key in extension settings"
              exit 1
            }
            $project = "chef-ice"
          }
        }
        # install.ps1's "task"/"service" daemon modes pass ADDLOCAL="ChefClientFeature,..."
        # to msiexec - legacy omnibus MSI feature names that chef-ice's Habitat-packaged
        # MSI doesn't define, so msiexec fails with error 2711 (exit 1603) before
        # chef-ice is ever installed. Default chef-ice to "auto" (no ADDLOCAL) unless
        # a daemon setting was explicitly requested.
        # ponytail: revisit once chef-ice's MSI exposes equivalent scheduled-task feature ids.
        if ($project -eq "chef-ice" -and -Not $daemon_setting) {
          $daemon = "auto"
        }

        # chefdownload-commercial.chef.io requires license_id on the install.ps1 fetch
        # itself, not just the `install` function call below - without it the endpoint
        # returns a plain-text error instead of a script.
        $install_ps1_url = 'https://chefdownload-commercial.chef.io/install.ps1'
        if ( $chef_license_key ) {
          # Use ${...} to unambiguously delimit the variable name before the
          # literal "?" - some PowerShell versions can otherwise misparse
          # "$var?text" inside a double-quoted string.
          $install_ps1_url = "${install_ps1_url}?license_id=$chef_license_key"
        }
        iex (new-object net.webclient).downloadstring($install_ps1_url)
        if ( $chef_license_key ) {
          # install.ps1's `install` function has no -license_id parameter (unlike
          # install.sh's -l flag) - resolve the licensed download URL ourselves via
          # the metadata endpoint and pass it through -download_url_override instead.
          Write-Host "Using chef_license_key for licensed commercial download"
          $arch = "x86_64"
          if ([Environment]::Is64BitOperatingSystem -eq $false) { $arch = "i386" }
          $os_version = (Get-CimInstance Win32_OperatingSystem).Version
          $meta_url = "https://chefdownload-commercial.chef.io/$chef_package_channel/$project/metadata?p=windows&pv=$os_version&m=$arch&license_id=$chef_license_key"
          if ( $chef_package_version -ne "latest" ) {
            $meta_url = "$meta_url&v=$chef_package_version"
          }
          $download_url = $null
          $download_version = $null
          try {
            $meta = (Invoke-WebRequest -Uri $meta_url -UseBasicParsing).Content | ConvertFrom-Json
            $download_url = $meta.url
            $download_version = $meta.version
          } catch {
            Write-Warning "Could not resolve licensed download URL ($($_.Exception.Message)); falling back to unlicensed install"
          }
          if ( $download_url ) {
            Write-Host "Downloading $project with license_id from $download_url"
            # install.ps1's Install-Project still calls Get-ProjectFileName (which
            # uses a hardcoded free/demo license_id) to derive -filename unless it
            # is passed explicitly, so derive it here ourselves - the metadata
            # endpoint's "url" has no usable filename in its path (it's just
            # ".../download?...") to avoid that unlicensed lookup interfering.
            $download_filename = "$project-$download_version-$arch.msi"
            $download_path = Join-Path $env:temp $download_filename
            install -project $project -daemon $daemon -version $chef_package_version -channel $chef_package_channel -download_url_override $download_url -filename $download_path
          } else {
            install -project $project -daemon $daemon -version $chef_package_version -channel $chef_package_channel
          }
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
    Catch {
      ## Catches WebException (and other errors) raised while downloading/installing
      ## the chef-client package. Not restricted to [System.Net.WebException] so that
      ## any unexpected error surfaces its real message instead of looping silently.
      if ($retrycount -ge $retries) {
        echo "Chef Infra Client Downloading failed after 3 retries."
        $ErrorMessage = $_.Exception.Message
        # log to CommandExecution log:
        echo "Error running install: $ErrorMessage"
        exit 1
      } else {
        echo "Chef Infra Client package download failed ($($_.Exception.GetType().FullName): $($_.Exception.Message)). Retrying in 20s..."
        sleep 20
        $retrycount++
      }
    }
  }
  if ($project -eq "chef-ice") {
    # Habitat packages don't binlink dependency executables - C:\hab\bin only
    # has hab.exe itself. ruby/gem for chef-ice live in the separate
    # core/ruby* runtime-dependency package, so find and add its bin dir too
    # (mirrors the equivalent Linux /hab/pkgs/core/ruby* fix).
    # ponytail: naive newest-version pick via sort; switch to `hab pkg path core/ruby3_4` if hab's guaranteed on PATH.
    $ruby_bin = Get-ChildItem -Path "C:\hab\pkgs\core" -Filter "ruby*" -Directory -ErrorAction SilentlyContinue |
      Sort-Object Name |
      ForEach-Object { Get-ChildItem -Path $_.FullName -Recurse -Filter "ruby.exe" -ErrorAction SilentlyContinue } |
      Select-Object -Last 1 |
      ForEach-Object { $_.DirectoryName }
    if ($ruby_bin) {
      $env:Path = "$ruby_bin;C:\hab\bin;" + $env:Path
    } else {
      $env:Path = "C:\hab\bin;" + $env:Path
    }
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
