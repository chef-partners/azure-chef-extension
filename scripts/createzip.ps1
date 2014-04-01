
$buildDir = [System.IO.Path]::GetFullPath($args[0])
$chefPackageName = $args[1]
$sourceDir = [System.IO.Path]::GetFullPath($args[2])
$machineOS = $args[3]
$machineArch = $args[4]
$chefVersion = $args[5]

function Chef-Get-ScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

$scriptDir = Chef-Get-ScriptDirectory

$chefExtensionRoot = [System.IO.Path]::GetFullPath("$scriptDir\\..")

$installerDir= "$chefExtensionRoot\\ChefExtensionHandler\\installer"

function Download-Chef-Client-Pkg
{
  if ( !(Test-Path $installerDir) ) {
    write-host "Chef Installer directory not found, creating $installerDir."
    mkdir $installerDir
  } else {
    # TODO: If chef installer already exist, and its version and user specified version both are same then don't download/remove existance installer
    Remove-Item $installerDir\\*
  }

  $localPath = "$installerDir\\chef-client-latest.msi"

  $remoteUrl="https://www.opscode.com/chef/download?p=windows&pv=$machineOS&m=$machineArch"

  if ( $chefVersion -ne $null ) {
    $remoteUrl += "&v=$chefVersion"
  }


  $webClient = new-object System.Net.WebClient
  write-host "remoteUrl::::$remoteUrl::::localPath:::$localPath"
  $webClient.DownloadFile($remoteUrl, $localPath)
  if ( $? -eq $True ) {
    write-host "Download via PowerShell succeeded"
  } else {
    write-host "Failed to download $remoteUrl. with status code $LASTEXITCODE"
    exit 1
  }
}

# Courtesy http://blogs.msdn.com/b/daiken/archive/2007/02/12/compress-files-with-windows-powershell-then-package-a-windows-vista-sidebar-gadget.aspx
function Add-Zip
{
  param([string]$zipfilename)

  if(-not (test-path($zipfilename)))
  {
    echo "Creating zip file $zipfilename..."
    set-content $zipfilename ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
    (dir $zipfilename).IsReadOnly = $false
  }

  $shellApplication = new-object -com shell.application
  $zipPackage = $shellApplication.NameSpace($zipfilename)

  foreach($file in $input)
  {
    echo "Adding $file to the zip"
    $zipPackage.CopyHere($file.FullName)

    while($zipPackage.Items().Item($file.Name) -Eq $null) {
        start-sleep -seconds 1
        write-host "." -nonewline
    }
  }
  echo "Created zip successfully."
}

write-host "Downloading chef client package..."
Download-Chef-Client-Pkg

# Main
if ( !(Test-Path $buildDir) ) {
  echo "Build directory not found, creating $buildDir."
  mkdir $buildDir
}

echo "Creating package from $sourceDir..."
Get-ChildItem "$sourceDir" | Add-Zip "$buildDir\$chefPackageName"