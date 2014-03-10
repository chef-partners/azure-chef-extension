

# uninstall chef
# Actions:
#    - disable chef service and remove service
#    - uninstall chef

$bootstrapDirectory = "C:\\chef"
$chefInstallDirectory = "C:\\opscode"

$env:Path += ";C:\opscode\chef\bin;C:\opscode\chef\embedded\bin"

# uninstall does both disable and remove the service
chef-service-manager -a uninstall

# Actual uninstall functionality
# Get chef_pkg by matching "chef client " string with $_.Name
$chef_pkg = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name.contains("Chef Client") }

# Uninstall chef_pkg
$chef_pkg.Uninstall()

# clean up config files and install folder
if (Test-Path $bootstrapDirectory) {
  Remove-Item -Recurse -Force $bootstrapDirectory
}
if (Test-Path $chefInstallDirectory) {
  Remove-Item -Recurse -Force $chefInstallDirectory
}