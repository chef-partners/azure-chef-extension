
$targetDir = [System.IO.Path]::GetFullPath($args[0])
$chefExtensionName = $args[1]
$sourceDir = [System.IO.Path]::GetFullPath($args[2])

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

# Main
if ( !(Test-Path $targetDir) ) {
  echo "Target directory not found, creating $targetDir."
  mkdir $targetDir
}

echo "Creating zip package from $sourceDir..."
Get-ChildItem "$sourceDir" | Add-Zip "$targetDir\$chefExtensionName"