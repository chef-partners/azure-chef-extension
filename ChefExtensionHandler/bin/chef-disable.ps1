# Source the shared PS
$chefExtensionRoot = ("{0}{1}" -f (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition), "\..")
. $chefExtensionRoot\bin\shared.ps1

Write-ChefStatus "stopping-chef-service" "transitioning"

# Call chef service manager to stop the chef service
$env:Path += ";C:\opscode\chef\bin;C:\opscode\chef\embedded\bin"

# stop the chef service
$result = chef-service-manager -a stop

if ($result -match "Service 'chef-client' is now 'stopped'.")
{
  Write-ChefStatus "chef-service-stop" "success"
}
else
{
  Write-ChefStatus "chef-service" "error" $result
}