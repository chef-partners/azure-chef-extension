
$buildDir = [System.IO.Path]::GetFullPath($args[0])
$chefPackageName = $args[1]
$sourceDir = [System.IO.Path]::GetFullPath($args[2])
$machineOS = $args[3]
$machineArch = $args[4]

if ($args[5] -ne $null) {
  $chefVersion = $args[5]
  $chefVersion = ($chefVersion -split '\.|\-')
  $chefVersion = ($chefVersion[0..2] -join("."))+"-$($chefVersion[3])"
}

function Chef-Get-ScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

$scriptDir = Chef-Get-ScriptDirectory

$chefExtensionRoot = [System.IO.Path]::GetFullPath("$scriptDir\\..")

$installerDir= "$chefExtensionRoot\\ChefExtensionHandler\\installer"

function Get-Property ($Object, $PropertyName, [object[]]$ArgumentList) {
  return $Object.GetType().InvokeMember($PropertyName, 'Public, Instance, GetProperty', $null, $Object, $ArgumentList)
}

function Invoke-Method ($Object, $MethodName, $ArgumentList) {
  return $Object.GetType().InvokeMember($MethodName, 'Public, Instance, InvokeMethod', $null, $Object, $ArgumentList)
}

function Get-Chef-Installer-Version($Path) {
  $msiOpenDatabaseModeReadOnly = 0
  $installer = New-Object -ComObject WindowsInstaller.Installer
  $database = Invoke-Method $installer OpenDatabase  @($Path, $msiOpenDatabaseModeReadOnly)
  $view = Invoke-Method $database OpenView @("SELECT Value FROM Property WHERE Property='ProductVersion'")
  Invoke-Method $view Execute
  $record = Invoke-Method $view Fetch
  $productVersion = $null

  if ($record) {
    $productVersion = (Get-Property $record StringData 1)
  }

  Invoke-Method $view Close @()
  Remove-Variable -Name record, view, database, installer

  $productVersion
}

function Download-Chef-Client-Pkg
{
  $localPath = "$installerDir\\chef-client-latest.msi"
  $remoteUrl="https://www.opscode.com/chef/download?p=windows&pv=$machineOS&m=$machineArch"

  if ( !(Test-Path $installerDir) ) {
    Write-Host "Chef Installer directory not found, creating $installerDir."
    mkdir $installerDir
  }

  if ( (Test-Path $localPath) -and $chefVersion -ne $null -and (Get-Chef-Installer-Version $localPath) -eq ($chefVersion -replace("-", ".")) ) {
    Write-Host "Chef Client installer already exist, skipping downloading..."
  } else {

    # TODO: Fix issue: Unable to remove existing file because another process using it
    Remove-Item -Force -path "$installerDir\\*"

    if ( $chefVersion -ne $null ) {
      $remoteUrl += "&v=$chefVersion"
    }

    $webClient = new-object System.Net.WebClient
    $webClient.DownloadFile($remoteUrl, $localPath)

    if ( $? -eq $True ) {
      Write-Host "Download via PowerShell succeeded"
    } else {
      Write-Host "Failed to download $remoteUrl. with status code $LASTEXITCODE"
      exit 1
    }
  }
}

function Build-ChefExtensionGem
{
  $gemFilePath = "$chefExtensionRoot\\azure-chef-extension.gemspec"
  $gemsDir = "$chefExtensionRoot\\ChefExtensionHandler\\gems"

  if ( !(Test-Path $gemsDir) ) {
    Write-Host "gems directory not found, creating $gemsDir ."
    mkdir $gemsDir
  }

  if ( (Test-Path $gemFilePath) ) {
    gem build $gemFilePath
    Get-ChildItem $chefExtensionRoot\\* -Filter *azure-chef-extension-* -Include *.gem* | Move-Item -Force -Destination $gemsDir
  } else {
    Write-Host "Gem build Failed...Not found gemspec file"
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
        Write-Host "." -nonewline
    }
  }
  echo "Created zip successfully."
}

Write-Host "Building Chef Extension Gem"
Build-ChefExtensionGem

Write-Host "Downloading chef client package..."
Download-Chef-Client-Pkg

# Main
if ( !(Test-Path $buildDir) ) {
  echo "Build directory not found, creating $buildDir."
  mkdir $buildDir
}

echo "Creating package from $sourceDir..."
Get-ChildItem "$sourceDir" | Add-Zip "$buildDir\$chefPackageName"