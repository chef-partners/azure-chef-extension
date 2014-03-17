

# uninstall chef
# Actions:
#    - disable chef service and remove service
#    - uninstall chef

$bootstrapDirectory = "C:\\chef"
$chefInstallDirectory = "C:\\opscode"

# uninstall does both disable and remove the service
chef-service-manager -a uninstall

# Uninstall the custom gem
gem uninstall -Ix azure-chef-extension

# Actual uninstall functionality
# Get chef_pkg by matching "chef client " string with $_.Name
$chef_pkg = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name.contains("Chef Client") }

# Uninstall chef_pkg
$chef_pkg.Uninstall()

# clean up config files and install folder
Remove-Item -Recurse -Force $bootstrapDirectory
Remove-Item -Recurse -Force $chefInstallDirectory