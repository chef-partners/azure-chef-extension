function Update-ChefExtensionRegistry
 {
   param (
    $Path = "HKCU:\Software\chef_extn",
    $Name = "Status",
    [Parameter(Mandatory=$True,Position=1)]
    [string]$Value
  )
echo "----------$Value"
  # Create registry entry, with Status=updated
  if (Test-Path -Path $Path -PathType Container) {
    #New-ItemProperty -Path $Path -Force -Name $Name -Value $Value
  }
  else {
   # New-Item -Path $Path -Force -Name $Name -Value $Value
  }
 }

Update-ChefExtensionRegistry "updated"